// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ConstantsV2} from "./ConstantsV2.sol";
import {DenyHelperV2, Address} from "./DenyHelperV2.sol";
import {KeyperRoles} from "./KeyperRoles.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";

contract KeyperModuleV2 is Auth, ReentrancyGuard, ConstantsV2, DenyHelperV2 {
    using GnosisSafeMath for uint256;
    using Address for address;
    /// @dev Definition of Safe module

    string public constant NAME = "Keyper Module";
    string public constant VERSION = "0.2.0";
    /// @dev Control Nonce of the module
    uint256 public nonce;
    /// @dev Safe contracts
    address public immutable masterCopy;
    address public immutable proxyFactory;
    address internal constant SENTINEL_OWNERS = address(0x1);
    /// @dev RoleAuthority
    address public rolesAuthority;
    /// @dev Enum Types

    enum Tier {
        GROUP, // 0
        ROOT // 1
    }
    /// @devStruct for Group
    /// @param tier Kind of the group (at the momento only GROUP or ROOT)
    /// @param name String name of the group (any tier of group)
    /// @param lead Address of Safe Lead of the group (Safe Lead Role)
    /// @param safe Address of Safe of the group (Safe Role)
    /// @param child Array of ID's members of the group
    /// @param superSafe ID of Superior Group (superSafe Role)

    struct Group {
        Tier tier;
        string name;
        address lead;
        address safe;
        uint256[] child;
        uint256 superSafe;
    }
    /// @dev Array of Orgs (based on Hash(DAO's name))

    bytes32[] private orgId;
    /// @dev indexId of the group
    uint256 public indexId;
    /// @dev Index of Group
    /// @dev Hash(DAO's name) -> ID's Groups
    mapping(bytes32 => uint256[]) public indexGroup;
    /// @dev Hash(DAO's name) -> Groups
    /// bytes32: Hash(DAO's name).   uint256:GroupId.   Group: Group Info
    mapping(bytes32 => mapping(uint256 => Group)) public groups;

    /// @dev Events
    event OrganizationCreated(
        address indexed creator, bytes32 indexed org, string name
    );

    event GroupCreated(
        bytes32 indexed org,
        uint256 indexed group,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );

    event GroupRemoved(
        bytes32 indexed org,
        uint256 indexed groupRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    event GroupSuperUpdated(
        bytes32 indexed org,
        uint256 indexed oldGroup,
        uint256 callerId,
        address indexed updater,
        uint256 newSuperSafe
    );

    event TxOnBehalfExecuted(
        bytes32 indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    event ModuleEnabled(address indexed safe, address indexed module);

    event RootSafeGroupCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeGroup,
        address indexed creator,
        address newRootSafeGroup,
        string name
    );

    /// @dev Errors
    error OrgNotRegistered(bytes32 org);
    error GroupNotRegistered(uint256 group);
    error SuperSafeNotRegistered(uint256 superSafe);
    error NotAuthorizedAddOwnerWithThreshold();
    error NotAuthorizedRemoveGroupFromOtherTree();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedAsNotSafeLead();
    error NotAuthorizedAsNotSuperSafe();
    error NotAuthorizedUpdateNonChildrenGroup();
    error NotAuthorizedSetRoleAnotherTree();
    error OwnerNotFound();
    error OwnerAlreadyExists();
    error CreateSafeProxyFailed();
    error InvalidThreshold();
    error TxExecutionModuleFaild();
    error ChildAlreadyExist();
    error InvalidGnosisSafe(address safe);
    error InvalidGnosisRootSafe(address safe);
    error SetRoleForbidden(Role role);
    error OrgAlreadyRegistered();
    error EmptyName();
    error UserNotGroup(address user);

    /// @dev Modifier for Validate if Org Exist or Not
    modifier OrgRegistered(bytes32 org) {
        if (!isOrgRegistered(org)) {
            revert OrgNotRegistered(org);
        }
        _;
    }

    /// @dev Modifier for Validate if Org/Group Exist or SuperSafeNotRegistered Not
    modifier GroupRegistered(bytes32 org, uint256 group) {
        if (groups[org][group].safe == address(0)) {
            revert GroupNotRegistered(group);
        }
        _;
    }

    /// @dev Modifier for Validate if the address is a Gnosis Safe Multisig Wallet
    modifier IsGnosisSafe(address safe) {
        if (safe == address(0) || !isSafe(safe)) {
            revert InvalidGnosisSafe(safe);
        }
        _;
    }

    /// @dev Modifier for Validate if the address is a Gnosis Safe Multisig Wallet and Root Safe
    modifier IsRootSafe(bytes32 org, address safe) {
        if (
            safe == address(0) || !isSafe(safe)
                || groups[org][getGroupIdBySafe(org, safe)].tier != Tier.ROOT
        ) {
            revert InvalidGnosisRootSafe(safe);
        }
        _;
    }

    constructor(
        address masterCopyAddress,
        address proxyFactoryAddress,
        address authorityAddress
    ) Auth(address(0), Authority(authorityAddress)) {
        if (
            masterCopyAddress == address(0) || proxyFactoryAddress == address(0)
                || authorityAddress == address(0)
        ) revert ZeroAddressProvided();

        if (
            !masterCopyAddress.isContract() || !proxyFactoryAddress.isContract()
        ) revert InvalidAddressProvided();

        masterCopy = masterCopyAddress;
        proxyFactory = proxyFactoryAddress;
        rolesAuthority = authorityAddress;
        indexId = 1;
    }

    function createSafeProxy(address[] memory owners, uint256 threshold)
        external
        returns (address safe)
    {
        bytes memory internalEnableModuleData = abi.encodeWithSignature(
            "internalEnableModule(address)", address(this)
        );

        bytes memory data = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            this,
            internalEnableModuleData,
            FALLBACK_HANDLER,
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        IGnosisSafeProxy gnosisSafeProxy = IGnosisSafeProxy(proxyFactory);
        try gnosisSafeProxy.createProxy(masterCopy, data) returns (
            address newSafe
        ) {
            return newSafe;
        } catch {
            revert CreateSafeProxyFailed();
        }
    }

    /// @notice Calls execTransaction of the safe with custom checks on owners rights
    /// @param org Organisation
    /// @param targetSafe Safe target address
    /// @param to data
    function execTransactionOnBehalf(
        bytes32 org,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    )
        external
        payable
        Denied(org, to)
        nonReentrant
        requiresAuth
        returns (bool result)
    {
        if (targetSafe == address(0) || to == address(0)) {
            revert ZeroAddressProvided();
        }
        if (isOrgRegistered(org)) {
            revert OrgNotRegistered(org);
        }
        if (!isSafe(targetSafe)) {
            revert InvalidGnosisSafe(targetSafe);
        }
        address caller = _msgSender();
        if (isSafe(caller)) {
            // Check caller is a lead or superSafe of the target safe (checking with isTreeMember because is the same method!!)
            if (
                isSafeLead(org, getGroupIdBySafe(org, targetSafe), caller)
                    || isTreeMember(
                        org,
                        getGroupIdBySafe(org, caller),
                        getGroupIdBySafe(org, targetSafe)
                    )
            ) {
                // Caller is a safe then check caller's safe signatures.
                bytes memory keyperTxHashData = encodeTransactionData(
                    /// Keyper Info
                    caller,
                    targetSafe,
                    /// Transaction info
                    to,
                    value,
                    data,
                    operation,
                    /// Signature info
                    nonce
                );

                IGnosisSafe gnosisLeadSafe = IGnosisSafe(caller);
                gnosisLeadSafe.checkSignatures(
                    keccak256(keyperTxHashData), keyperTxHashData, signatures
                );
            } else {
                revert NotAuthorizedExecOnBehalf();
            }
        } else {
            // Caller is EAO (lead) : check if it has the rights over the target safe
            if (!isSafeLead(org, getGroupIdBySafe(org, targetSafe), caller)) {
                revert NotAuthorizedAsNotSafeLead();
            }
        }

        /// Increase nonce and execute transaction.
        nonce++;
        /// Execute transaction from target safe
        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
        result = gnosisTargetSafe.execTransactionFromModule(
            to, value, data, operation
        );

        emit TxOnBehalfExecuted(org, caller, targetSafe, result);
    }

    function internalEnableModule(address module)
        external
        validAddress(module)
    {
        this.enableModule(module);
    }

    /// @dev Non-executed code, function called by the new safe
    function enableModule(address module) external validAddress(module) {
        emit ModuleEnabled(address(this), module);
    }

    /// @notice This function will allow Safe Lead & Safe Lead modify only roles to to add owner and set a threshold without passing by normal multisig check
    /// @dev For instance role
    function addOwnerWithThreshold(
        address ownerAdded,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    )
        external
        OrgRegistered(org)
        validAddress(ownerAdded)
        requiresAuth
        IsGnosisSafe(targetSafe)
    {
        address caller = _msgSender();
        /// Check _msgSender() is an Root/Super/Lead safe of the target safe
        if (
            !isRootSafeOf(org, caller, getGroupIdBySafe(org, targetSafe))
                && !isSuperSafe(
                    org,
                    getGroupIdBySafe(org, caller),
                    getGroupIdBySafe(org, targetSafe)
                ) && !isSafeLead(org, getGroupIdBySafe(org, targetSafe), caller)
        ) {
            revert NotAuthorizedAddOwnerWithThreshold();
        }

        /// If the owner is already an owner
        if (isSafeOwner(IGnosisSafe(targetSafe), ownerAdded)) {
            revert OwnerAlreadyExists();
        }

        /// if threshold is invalid
        if (
            threshold < 1
                || threshold > (IGnosisSafe(targetSafe).getOwners().length.add(1))
        ) {
            revert InvalidThreshold();
        }

        bytes memory data = abi.encodeWithSelector(
            IGnosisSafe.addOwnerWithThreshold.selector, ownerAdded, threshold
        );
        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
        /// Execute transaction from target safe
        bool result = gnosisTargetSafe.execTransactionFromModule(
            targetSafe, uint256(0), data, Enum.Operation.Call
        );
        if (!result) revert TxExecutionModuleFaild();
    }

    /// @notice This function will allow UserLead to remove an owner
    /// @dev For instance role
    function removeOwner(
        address prevOwner,
        address ownerRemoved,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    ) external OrgRegistered(org) requiresAuth IsGnosisSafe(targetSafe) {
        if (prevOwner == address(0) || ownerRemoved == address(0)) {
            revert ZeroAddressProvided();
        }
        /// Check _msgSender() is an user lead of the target safe
        if (!isSafeLead(org, getGroupIdBySafe(org, targetSafe), _msgSender())) {
            revert NotAuthorizedAsNotSafeLead();
        }

        /// if Owner Not found
        if (!isSafeOwner(IGnosisSafe(targetSafe), ownerRemoved)) {
            revert OwnerNotFound();
        }

        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);

        bytes memory data = abi.encodeWithSelector(
            IGnosisSafe.removeOwner.selector, prevOwner, ownerRemoved, threshold
        );

        /// Execute transaction from target safe
        bool result = gnosisTargetSafe.execTransactionFromModule(
            targetSafe, uint256(0), data, Enum.Operation.Call
        );
        if (!result) revert TxExecutionModuleFaild();
    }

    /// @notice Give user roles
    /// @dev Call must come from the root safe
    /// @param role Role to be assigned
    /// @param user User that will have specific role
    /// @param group Safe group which will have the user permissions on
    function setRole(Role role, address user, uint256 group, bool enabled)
        external
        validAddress(user)
        requiresAuth
    {
        if (role == Role.ROOT_SAFE || role == Role.SUPER_SAFE) {
            revert SetRoleForbidden(role);
        }
        bytes32 org = getOrgByGroup(group);
        if (!isRootSafeOf(org, _msgSender(), group)) {
            revert NotAuthorizedSetRoleAnotherTree();
        }
        Group storage safeGroup = groups[org][group];
        // Check if group is part of the caller org
        if (
            role == Role.SAFE_LEAD || role == Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY
                || role == Role.SAFE_LEAD_MODIFY_OWNERS_ONLY
        ) {
            // Update group/org lead
            safeGroup.lead = user;
        }
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(user, uint8(role), enabled);
    }

    /// @notice Register an organization
    /// @dev Call has to be done from a safe transaction
    /// @param daoName String with of the org (This name will be hashed into smart contract)
    function registerOrg(string calldata daoName)
        external
        IsGnosisSafe(_msgSender())
    {
        if (bytes(daoName).length == 0) {
            revert EmptyName();
        }
        bytes32 name = bytes32(keccak256(abi.encodePacked(daoName)));
        if (isOrgRegistered(name)) {
            revert OrgAlreadyRegistered();
        }
        address caller = _msgSender();
        // when register an org, need to create the first root safe group
        groups[name][indexId] = Group({
            tier: Tier.ROOT,
            name: daoName,
            lead: address(0),
            safe: caller,
            child: new uint256[](0),
            superSafe: 0
        });
        orgId.push(name);
        indexGroup[name].push(indexId);
        indexId++;

        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(caller, uint8(Role.ROOT_SAFE), true);
        _authority.setUserRole(caller, uint8(Role.SUPER_SAFE), true);

        emit OrganizationCreated(caller, name, daoName);
    }

    /// @notice Call has to be done from another root safe to the organization
    /// @dev Call has to be done from a safe transaction
    /// @param org bytes32 of the organization
    /// @param name string name of the group
    function createRootSafeGroup(
        bytes32 org,
        address newRootSafe,
        string calldata name
    )
        external
        OrgRegistered(org)
        IsGnosisSafe(newRootSafe)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        if (bytes(name).length == 0) {
            revert EmptyName();
        }
        uint256 newIndex = indexId;
        groups[org][newIndex] = Group({
            tier: Tier.ROOT,
            name: name,
            lead: address(0),
            safe: newRootSafe,
            child: new uint256[](0),
            superSafe: 0
        });
        indexGroup[org].push(newIndex);
        indexId++;

        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(newRootSafe, uint8(Role.ROOT_SAFE), true);
        authority.setUserRole(newRootSafe, uint8(Role.SUPER_SAFE), true);

        emit RootSafeGroupCreated(
            org, newIndex, _msgSender(), newRootSafe, name
            );
    }

    /// @notice Add a group to an organization/group
    /// @dev Call coming from the group safe
    /// @param org bytes32 of the organization
    /// @param superSafe address of the superSafe
    /// @param name string name of the group
    /// TODO: how avoid any safe adding in the org or group?
    function addGroup(bytes32 org, uint256 superSafe, string memory name)
        external
        OrgRegistered(org)
        GroupRegistered(org, superSafe)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        // check to verify if the caller is already exist in the org
        if (isChild(org, superSafe, caller)) revert ChildAlreadyExist();
        // check the name of group is not empty
        if (bytes(name).length == 0) revert EmptyName();
        /// Create a new group
        Group storage newGroup = groups[org][indexId];
        /// Add to org root/group
        Group storage superSafeOrgGroup = groups[org][superSafe];
        /// Add child to superSafe
        uint256 newIndex = indexId;
        superSafeOrgGroup.child.push(newIndex);

        newGroup.safe = caller;
        newGroup.name = name;
        newGroup.superSafe = superSafe;
        indexGroup[org].push(newIndex);
        indexId++;
        /// Give Role SuperSafe
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        if (
            (
                !_authority.doesUserHaveRole(
                    superSafeOrgGroup.safe, uint8(Role.SUPER_SAFE)
                )
            ) && (superSafeOrgGroup.child.length > 0)
        ) {
            _authority.setUserRole(
                superSafeOrgGroup.safe, uint8(Role.SUPER_SAFE), true
            );
        }

        emit GroupCreated(org, newIndex, newGroup.lead, caller, superSafe, name);
    }

    /// @notice Remove group and reasign all child to the superSafe
    /// @dev All actions will be driven based on the caller of the method, and args
    /// @param org id's of the organization
    /// @param group address of the group to be removed
    function removeGroup(bytes32 org, uint256 group)
        external
        OrgRegistered(org)
        GroupRegistered(org, group)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        uint256 rootSafe = getGroupIdBySafe(org, _msgSender());
        /// RootSafe usecase : Check if the group is part of caller's org
        /// TODO: i think this check is redundant because only care if is or not Tree Member
        if (
            (groups[org][rootSafe].tier == Tier.ROOT)
                && (!isTreeMember(org, rootSafe, group))
        ) {
            revert NotAuthorizedRemoveGroupFromOtherTree();
        }
        // SuperSafe usecase : Check caller is superSafe of the group
        if (!isSuperSafe(org, rootSafe, group)) {
            revert NotAuthorizedAsNotSuperSafe();
        }
        Group memory _group = groups[org][group];

        // superSafe is either an org or a group
        Group storage superSafe = groups[org][_group.superSafe];

        /// Remove child from superSafe
        for (uint256 i = 0; i < superSafe.child.length; i++) {
            if (superSafe.child[i] == group) {
                superSafe.child[i] = superSafe.child[superSafe.child.length - 1];
                superSafe.child.pop();
                break;
            }
        }
        // Handle child from removed group
        for (uint256 i = 0; i < _group.child.length; i++) {
            // Add removed group child to superSafe
            superSafe.child.push(_group.child[i]);
            Group storage childrenGroup = groups[org][_group.child[i]];
            // Update children group superSafe reference
            childrenGroup.superSafe = _group.superSafe;
        }

        // Revoke roles to group
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(_group.safe, uint8(Role.SUPER_SAFE), false);
        // Disable safe lead role
        disableSafeLeadRoles(_group.safe);

        // Store the name before to delete the Group
        emit GroupRemoved(
            org,
            group,
            superSafe.safe,
            _msgSender(),
            _group.superSafe,
            _group.name
            );
        removeIndexGroup(org, group);
        delete groups[org][group];
    }

    /// @notice update superSafe of a group
    /// @dev Update the superSafe of a group with a new superSafe, Call must come from the root safe
    /// @param group address of the group to be updated
    /// @param newSuper address of the new superSafe
    function updateSuper(bytes32 org, uint256 group, uint256 newSuper)
        public
        GroupRegistered(org, group)
        GroupRegistered(org, newSuper)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        address caller = _msgSender();
        uint256 callerId = getGroupIdBySafe(org, caller);
        /// RootSafe usecase : Check if the group is Member of the Tree of the caller (rootSafe)
        if (isRootSafeOf(org, caller, group)) {
            revert NotAuthorizedUpdateNonChildrenGroup();
        }
        Group storage _group = groups[org][group];
        /// SuperSafe is either an Org or a Group
        Group storage oldSuper = groups[org][_group.superSafe];

        /// Remove child from superSafe
        for (uint256 i = 0; i < oldSuper.child.length; i++) {
            if (oldSuper.child[i] == group) {
                oldSuper.child[i] = oldSuper.child[oldSuper.child.length - 1];
                oldSuper.child.pop();
                break;
            }
        }
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        /// Revoke SuperSafe and SafeLead if don't have any child, and is not organization
        if (oldSuper.child.length == 0) {
            _authority.setUserRole(oldSuper.safe, uint8(Role.SUPER_SAFE), false);
            /// TODO: verify if the oldSuper need or not the Safe Lead role (after MVP)
        }

        /// Update group superSafe
        _group.superSafe = newSuper;
        Group storage newSuperGroup = groups[org][newSuper];
        /// Add group to new superSafe
        /// Give Role SuperSafe if not have it
        if (
            !_authority.doesUserHaveRole(
                newSuperGroup.safe, uint8(Role.SUPER_SAFE)
            )
        ) {
            _authority.setUserRole(
                newSuperGroup.safe, uint8(Role.SUPER_SAFE), true
            );
        }
        newSuperGroup.child.push(group);
        emit GroupSuperUpdated(org, group, callerId, caller, newSuper);
    }

    /// List of the Methods of DenyHelpers override

    /// @dev Funtion to Add Wallet to the List based on Approach of Safe Contract - Owner Manager
    /// @param org ID's Org where the Wallet to be added to the List
    /// @param users Array of Address of the Wallet to be added to the List
    function addToList(bytes32 org, address[] memory users)
        external
        override
        OrgRegistered(org)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        if (users.length == 0) revert ZeroAddressProvided();
        if (!allowFeature[org] && !denyFeature[org]) {
            revert DenyHelpersDisabled();
        }
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (listed[org][wallet] != address(0)) {
                revert UserAlreadyOnList();
            }
            // Add wallet to List
            listed[org][currentWallet] = wallet;
            currentWallet = wallet;
        }
        listed[org][currentWallet] = SENTINEL_WALLETS;
        listCount[org] += users.length;
        emit AddedToList(users);
    }

    /// @dev Function to Drop Wallet from the List  based on Approach of Safe Contract - Owner Manager
    /// @param org Address of Org where the Wallet to be dropped of the List
    /// @param user Array of Address of the Wallet to be dropped of the List
    function dropFromList(bytes32 org, address user)
        external
        override
        validAddress(user)
        OrgRegistered(org)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        if (!allowFeature[org] && !denyFeature[org]) {
            revert DenyHelpersDisabled();
        }
        if (listCount[org] == 0) revert ListEmpty();
        if (!isListed(org, user)) revert InvalidAddressProvided();
        address prevUser = getPrevUser(org, user);
        listed[org][prevUser] = listed[org][user];
        listed[org][user] = address(0);
        listCount[org] = listCount[org] > 1 ? listCount[org].sub(1) : 0;
        emit DroppedFromList(user);
    }

    /// @dev Method to Enable Allowlist
    /// @param org Address of Org where will be enabled the Allowedlist
    function enableAllowlist(bytes32 org)
        external
        override
        OrgRegistered(org)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        allowFeature[org] = true;
        denyFeature[org] = false;
    }

    /// @dev Method to Enable Allowlist
    /// @param org Address of Org where will be enabled the Deniedlist
    function enableDenylist(bytes32 org)
        external
        override
        OrgRegistered(org)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        allowFeature[org] = false;
        denyFeature[org] = true;
    }

    /// @dev Method to Disable All
    function disableDenyHelper(bytes32 org)
        external
        override
        OrgRegistered(org)
        IsRootSafe(org, _msgSender())
        requiresAuth
    {
        allowFeature[org] = false;
        denyFeature[org] = false;
    }

    // List of Helpers

    function getGroupByName(string calldata org, uint256 group)
        public
        view
        OrgRegistered(bytes32(keccak256(abi.encodePacked(org))))
        GroupRegistered(bytes32(keccak256(abi.encodePacked(org))), group)
        returns (
            Tier,
            string memory,
            address,
            address,
            uint256[] memory,
            uint256
        )
    {
        bytes32 orgID = bytes32(keccak256(abi.encodePacked(org)));
        return (
            groups[orgID][group].tier,
            groups[orgID][group].name,
            groups[orgID][group].lead,
            groups[orgID][group].safe,
            groups[orgID][group].child,
            groups[orgID][group].superSafe
        );
    }

    /// @notice Get all the information about a group
    /// @dev Method for getting all info of a group
    /// @param org uint256 of the organization
    /// @param group uint256 of the group
    function getGroupInfo(bytes32 org, uint256 group)
        public
        view
        OrgRegistered(org)
        GroupRegistered(org, group)
        returns (
            Tier,
            string memory,
            address,
            address,
            uint256[] memory,
            uint256
        )
    {
        return (
            groups[org][group].tier,
            groups[org][group].name,
            groups[org][group].lead,
            groups[org][group].safe,
            groups[org][group].child,
            groups[org][group].superSafe
        );
    }

    /// @notice check if the organisation is registered
    /// @param org address
    /// @return bool
    function isOrgRegistered(bytes32 org) public view returns (bool) {
        if (groups[org][indexGroup[org][0]].safe == address(0)) return false;
        return true;
    }

    /// @notice Check if child address is part of the group within an organization
    /// @param org uint256 of the organization
    /// @param superSafe uint256 of the superSafe
    /// @param child address of the child
    /// @return bool
    function isChild(bytes32 org, uint256 superSafe, address child)
        public
        view
        returns (bool)
    {
        /// Check within orgs first if superSafe is an organisation
        if (!isOrgRegistered(org)) return false;
        /// Check within groups of the org
        if (groups[org][superSafe].safe == address(0)) {
            revert SuperSafeNotRegistered(superSafe);
        }
        Group memory group = groups[org][superSafe];
        for (uint256 i = 0; i < group.child.length; i++) {
            if (group.child[i] == getGroupIdBySafe(org, child)) return true;
        }
        return false;
    }

    /// @notice Check if the address, is a superSafe of the group within an organization
    /// @param org ID's of the organization
    /// @param group ID's of the child group/safe
    /// @param root address of Root Safe of the group
    /// @return bool
    function isRootSafeOf(bytes32 org, address root, uint256 group)
        public
        view
        returns (bool)
    {
        uint256 rootSafe = getGroupIdBySafe(org, root);
        return (
            (groups[org][rootSafe].tier == Tier.ROOT)
                && (isSuperSafe(org, rootSafe, group))
        );
    }

    /// @notice Check if the group is a superSafe of another group
    /// @param org ID's of the organization
    /// @param root ID's of root Safe
    /// @param group ID's of the group to check if is a Tree Member
    /// @return bool
    function isTreeMember(bytes32 org, uint256 root, uint256 group)
        public
        view
        returns (bool)
    {
        Group memory childGroup = groups[org][group];
        uint256 currentSuperSafe = childGroup.superSafe;
        /// TODO: probably more efficient to just create a superSafes mapping instead of this iterations
        while (currentSuperSafe != 0) {
            if (currentSuperSafe == root) return true;
            childGroup = groups[org][currentSuperSafe];
            currentSuperSafe = childGroup.superSafe;
        }
        return false;
    }

    /// @notice Check if the group is a superSafe of another group
    /// @param org ID's of the organization
    /// @param superSafe ID's of the superSafe
    /// @param group ID's of the group
    /// @return bool
    function isSuperSafe(bytes32 org, uint256 superSafe, uint256 group)
        public
        view
        returns (bool)
    {
        Group memory childGroup = groups[org][group];
        uint256 currentSuperSafe = childGroup.superSafe;
        /// TODO: probably more efficient to just create a superSafes mapping instead of this iterations
        while (currentSuperSafe != 0) {
            if (currentSuperSafe == superSafe) return true;
            childGroup = groups[org][currentSuperSafe];
            currentSuperSafe = childGroup.superSafe;
        }
        return false;
    }

    /// @dev Method to get Group ID by safe address
    /// @param org uint256 indexId of Organization
    /// @param safe Safe address
    /// @return Group ID
    function getGroupIdBySafe(bytes32 org, address safe)
        public
        view
        OrgRegistered(org)
        returns (uint256)
    {
        /// Check if the Safe address is into an Group mapping
        for (uint256 i = 0; i < indexGroup[org].length; i++) {
            if (groups[org][indexGroup[org][i]].safe == safe) {
                return indexGroup[org][i];
            }
        }
        return 0;
    }

    /// @notice Check if a user is an safe lead of a group/org
    /// @param org ID's of the organization
    /// @param group address of the group
    /// @param user address of the user that is a lead or not
    /// @return bool
    function isSafeLead(bytes32 org, uint256 group, address user)
        public
        view
        returns (bool)
    {
        Group memory _group = groups[org][group];
        if (_group.safe == address(0)) return false;
        if (_group.lead == user) {
            return true;
        }
        return false;
    }

    /// @notice Method to Validate if address is a Gnosis Safe Multisig Wallet
    /// @dev This method is used to validate if the address is a Gnosis Safe Multisig Wallet
    /// @param safe Address to validate
    /// @return bool
    function isSafe(address safe) public view returns (bool) {
        /// Check if the address is a Gnosis Safe Multisig Wallet
        if (safe.isContract()) {
            /// Check if the address is a Gnosis Safe Multisig Wallet
            bytes memory payload = abi.encodeWithSignature("getThreshold()");
            (bool success, bytes memory returnData) = safe.staticcall(payload);
            if (!success) return false;
            /// Check if the address is a Gnosis Safe Multisig Wallet
            uint256 threshold = abi.decode(returnData, (uint256));
            if (threshold == 0) return false;
            return true;
        } else {
            return false;
        }
    }

    /// @notice Check if the signer is an owner of the safe
    /// @dev Call has to be done from a safe transaction
    /// @param gnosisSafe GnosisSafe interface
    /// @param signer Address of the signer to verify
    /// @return bool
    function isSafeOwner(IGnosisSafe gnosisSafe, address signer)
        public
        view
        returns (bool)
    {
        address[] memory safeOwners = gnosisSafe.getOwners();
        for (uint256 i = 0; i < safeOwners.length; i++) {
            if (safeOwners[i] == signer) {
                return true;
            }
        }
        return false;
    }

    /// @notice call to get the orgId based on group id
    /// @dev Method to get the hashed orgId based on group id
    /// @param group uint256 of the group
    /// @return orgGroup bytes32
    function getOrgByGroup(uint256 group)
        public
        view
        returns (bytes32 orgGroup)
    {
        orgGroup = bytes32(0);
        for (uint256 i = 0; i < orgId.length; i++) {
            if (groups[orgId[i]][group].safe != address(0)) orgGroup = orgId[i];
        }
        if (orgGroup == bytes32(0)) revert GroupNotRegistered(group);
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this));
    }

    /// @dev Returns the chain id used by this contract.
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function encodeTransactionData(
        address caller,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    ) public view returns (bytes memory) {
        bytes32 keyperTxHash = keccak256(
            abi.encode(
                KEYPER_TX_TYPEHASH,
                caller,
                safe,
                to,
                value,
                keccak256(data),
                operation,
                _nonce
            )
        );
        return abi.encodePacked(
            bytes1(0x19), bytes1(0x01), domainSeparator(), keyperTxHash
        );
    }

    function getTransactionHash(
        address caller,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(
            encodeTransactionData(
                caller, safe, to, value, data, operation, _nonce
            )
        );
    }

    /// @notice disable safe lead roles
    /// @dev Associated roles: SAFE_LEAD || SAFE_LEAD_EXEC_ON_BEHALF_ONLY || SAFE_LEAD_MODIFY_OWNERS_ONLY
    /// @param user Address of the user to disable roles
    function disableSafeLeadRoles(address user) private {
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        if (_authority.doesUserHaveRole(user, uint8(Role.SAFE_LEAD))) {
            _authority.setUserRole(user, uint8(Role.SAFE_LEAD), false);
        } else if (
            _authority.doesUserHaveRole(
                user, uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            )
        ) {
            _authority.setUserRole(
                user, uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY), false
            );
        } else if (
            _authority.doesUserHaveRole(
                user, uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            )
        ) {
            _authority.setUserRole(
                user, uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY), false
            );
        }
    }

    /// @notice Private method to remove indexId from mapping of indexes into organizations
    /// @param org ID's of the organization
    /// @param group uint256 of the group
    function removeIndexGroup(bytes32 org, uint256 group) private {
        for (uint256 i = 0; i < indexGroup[org].length; i++) {
            if (indexGroup[org][i] == group) {
                indexGroup[org][i] = indexGroup[org][indexGroup[org].length - 1];
                indexGroup[org].pop();
                break;
            }
        }
    }
}
