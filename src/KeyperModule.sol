// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Constants} from "./Constants.sol";
import {DenyHelper, Address} from "./DenyHelper.sol";
import {console} from "forge-std/console.sol";
import {KeyperRoles} from "./KeyperRoles.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";

contract KeyperModule is Auth, ReentrancyGuard, Constants, DenyHelper {
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
    /// @devStruct for Group

    struct Group {
        string name;
        address lead;
        address safe;
        address[] child;
        address superSafe;
    }
    /// @dev Orgs -> Groups

    mapping(address => mapping(address => Group)) public groups;
    /// @dev Orgs info
    mapping(address => Group) public orgs;
    /// @dev Events

    event OrganizationCreated(address indexed org, string name);

    event GroupCreated(
        address indexed org,
        address indexed group,
        string name,
        address indexed lead,
        address superSafe
    );

    event GroupRemoved(
        address indexed org,
        address indexed groupRemoved,
        address indexed caller,
        address superSafe,
        string name
    );

    event GroupSuperUpdated(
        address indexed org,
        address indexed group,
        address indexed caller,
        address superSafe
    );

    event TxOnBehalfExecuted(
        address indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    event ModuleEnabled(address indexed safe, address indexed module);

    /// @dev Errors
    error OrgNotRegistered();
    error GroupNotRegistered(address group);
    error SuperSafeNotRegistered(address superSafe);
    error LeadNotRegistered();
    error NotAuthorized();
    error NotAuthorizedRemoveGroupFromOtherOrg();
    error NotAuthorizedUpdateGroupFromOtherOrg();
    error NotAuthorizedRemoveNonChildrenGroup();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedAsNotSafeLead();
    error OwnerNotFound();
    error OwnerAlreadyExists();
    error CreateSafeProxyFailed();
    error InvalidThreshold();
    error TxExecutionModuleFaild();
    error ChildAlreadyExist();
    error InvalidGnosisSafe();
    error ChildNotFound();
    error SetRoleForbidden(Role role);

    /// @dev Modifier for Validate if Org Exist or Not
    modifier OrgRegistered(address org) {
        if (org == address(0) || orgs[org].safe == address(0)) {
            revert OrgNotRegistered();
        }
        _;
    }

    /// @dev Modifier for Validate if Org/Group Exist or SuperSafeNotRegistered Not
    modifier GroupRegistered(address org, address group) {
        if (group == address(0) || groups[org][group].safe == address(0)) {
            revert GroupNotRegistered(group);
        }
        _;
    }

    /// @dev Modifier for Validate ifthe address is a Gnosis Safe Multisig Wallet
    modifier IsGnosisSafe(address safe) {
        if (safe == address(0) || !isSafe(safe)) {
            revert InvalidGnosisSafe();
        }
        _;
    }

    constructor(
        address masterCopyAddress,
        address proxyFactoryAddress,
        address authority
    ) Auth(address(0), Authority(authority)) {
        if (
            masterCopyAddress == address(0) || proxyFactoryAddress == address(0)
                || authority == address(0)
        ) revert ZeroAddressProvided();

        if (
            !masterCopyAddress.isContract() || !proxyFactoryAddress.isContract()
        ) revert InvalidAddressProvided();

        masterCopy = masterCopyAddress;
        proxyFactory = proxyFactoryAddress;
        rolesAuthority = authority;
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
        address org,
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
        if (org == address(0) || targetSafe == address(0) || to == address(0)) {
            revert ZeroAddressProvided();
        }
        if (!isSafe(targetSafe)) {
            revert InvalidGnosisSafe();
        }
        address caller = _msgSender();
        /// Check caller is a lead of the target safe
        if (
            !isSafeLead(org, caller, targetSafe)
                && !isSuperSafe(org, caller, targetSafe)
        ) {
            revert NotAuthorizedExecOnBehalf();
        }

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
        /// Increase nonce and execute transaction.
        nonce++;
        // If caller is a safe then check caller safe signatures.
        if (isSafe(caller)) {
            IGnosisSafe gnosisLeadSafe = IGnosisSafe(caller);
            gnosisLeadSafe.checkSignatures(
                keccak256(keyperTxHashData), keyperTxHashData, signatures
            );
        } else {
            // Caller is EAO (lead) : that has the rights over the target safe
            if (!isSafeLead(org, targetSafe, caller)) {
                revert NotAuthorizedAsNotSafeLead();
            }
        }

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
        address owner,
        uint256 threshold,
        address targetSafe,
        address org
    ) external OrgRegistered(org) requiresAuth IsGnosisSafe(targetSafe) {
        /// Check _msgSender() is an user lead of the target safe
        if (!isSafeLead(org, targetSafe, _msgSender())) {
            revert NotAuthorizedAsNotSafeLead();
        }

        /// If the owner is already an owner
        if (isSafeOwner(IGnosisSafe(targetSafe), owner)) {
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
            IGnosisSafe.addOwnerWithThreshold.selector, owner, threshold
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
        address owner,
        uint256 threshold,
        address targetSafe,
        address org
    ) external requiresAuth IsGnosisSafe(targetSafe) {
        if (prevOwner == address(0) || owner == address(0) || org == address(0))
        {
            revert ZeroAddressProvided();
        }
        /// Check _msgSender() is an user lead of the target safe
        if (!isSafeLead(org, targetSafe, _msgSender())) {
            revert NotAuthorizedAsNotSafeLead();
        }

        /// if Owner Not found
        if (!isSafeOwner(IGnosisSafe(targetSafe), owner)) {
            revert OwnerNotFound();
        }

        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);

        bytes memory data = abi.encodeWithSelector(
            IGnosisSafe.removeOwner.selector, prevOwner, owner, threshold
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
    function setRole(Role role, address user, address group, bool enabled)
        external
        validAddress(user)
        requiresAuth
    {
        if (role == Role.ROOT_SAFE || role == Role.SUPER_SAFE) {
            revert SetRoleForbidden(role);
        }
        if (
            role == Role.SAFE_LEAD || role == Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY
                || role == Role.SAFE_LEAD_MODIFY_OWNERS_ONLY
        ) {
            Group storage safeGroup;
            if (_msgSender() == group) {
                // Check org validity
                if (!isOrgRegistered(_msgSender())) revert OrgNotRegistered();
                safeGroup = orgs[_msgSender()];
            } else {
                // Check if group is part of the caller org
                if (groups[_msgSender()][group].safe == address(0)) {
                    revert GroupNotRegistered(group);
                }
                safeGroup = groups[_msgSender()][group];
            }
            // Update group/org lead
            safeGroup.lead = user;
        }
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(user, uint8(role), enabled);
    }

    /// @notice Register an organisatin
    /// @dev Call has to be done from a safe transaction
    /// @param name of the org
    function registerOrg(string memory name)
        external
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        Group storage rootOrg = orgs[caller];
        rootOrg.name = name;
        rootOrg.safe = caller;

        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(caller, uint8(Role.ROOT_SAFE), true);
        authority.setUserRole(caller, uint8(Role.SUPER_SAFE), true);

        emit OrganizationCreated(caller, name);
    }

    /// @notice Add a group to an organization/group
    /// @dev Call coming from the group safe
    /// @param org address of the organization
    /// @param superSafe address of the superSafe
    /// @param name name of the group
    /// TODO: how avoid any safe adding in the org or group?
    function addGroup(address org, address superSafe, string memory name)
        external
        OrgRegistered(org)
        validAddress(superSafe)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        if (isChild(org, superSafe, caller)) revert ChildAlreadyExist();
        if (org != superSafe && groups[org][superSafe].safe == address(0)) {
            revert GroupNotRegistered(superSafe);
        }
        Group storage newGroup = groups[org][caller];
        /// Add to org root/group
        Group storage superSafeOrgGroup =
            (superSafe == org) ? orgs[org] : groups[org][superSafe];
        superSafeOrgGroup.child.push(caller);
        /// By default Lead of the new group is the Lead of the superSafe (TODO check this)
        newGroup.lead = superSafeOrgGroup.lead;
        newGroup.safe = caller;
        newGroup.name = name;
        newGroup.superSafe = superSafe;
        /// Give Role SuperSafe
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        if (
            (!authority.doesUserHaveRole(superSafe, uint8(Role.SUPER_SAFE)))
                && (superSafe != org) && (superSafeOrgGroup.child.length > 0)
        ) {
            authority.setUserRole(superSafe, uint8(Role.SUPER_SAFE), true);
        }

        emit GroupCreated(org, caller, name, newGroup.lead, superSafe);
    }

    /// @notice Remove group and reasign all child to the superSafe
    /// @dev All actions will be driven based on the caller of the method, and args
    /// @param org address of the organization
    /// @param group address of the group to be removed
    function removeGroup(address org, address group)
        external
        OrgRegistered(org)
        GroupRegistered(org, group)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        address caller = _msgSender();
        // RootSafe usecase : Check if the group is part of caller's org
        if (caller == org) {
            if (groups[caller][group].safe == address(0)) {
                revert NotAuthorizedRemoveGroupFromOtherOrg();
            }
        } else {
            // SuperSafe usecase : Check caller is superSafe of the group
            if (!isSuperSafe(org, caller, group)) {
                revert NotAuthorizedRemoveNonChildrenGroup();
            }
        }

        Group memory _group = groups[org][group];

        // superSafe is either an org or a group
        Group storage superSafe =
            _group.superSafe == org ? orgs[org] : groups[org][_group.superSafe];

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
            childrenGroup.superSafe = superSafe.safe;
        }

        // Revoke roles to group
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(group, uint8(Role.SUPER_SAFE), false);
        // Disable safe lead role
        disableSafeLeadRoles(_group.superSafe);

        // Store the name before to delete the Group
        emit GroupRemoved(org, group, caller, superSafe.safe, _group.name);
        delete groups[org][group];
    }

    // List of the Methods of DenyHelpers override

    /// @dev Funtion to Add Wallet to the List based on Approach of Safe Contract - Owner Manager
    /// @param org Address of Org where the Wallet to be added to the List
    /// @param users Array of Address of the Wallet to be added to the List
    function addToList(address org, address[] memory users)
        external
        override
        OrgRegistered(org)
        IsGnosisSafe(_msgSender())
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
    function dropFromList(address org, address user)
        external
        override
        validAddress(user)
        OrgRegistered(org)
        IsGnosisSafe(_msgSender())
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
    function enableAllowlist(address org)
        external
        override
        OrgRegistered(org)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        allowFeature[org] = true;
        denyFeature[org] = false;
    }

    /// @dev Method to Enable Allowlist
    /// @param org Address of Org where will be enabled the Deniedlist
    function enableDenylist(address org)
        external
        override
        OrgRegistered(org)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        allowFeature[org] = false;
        denyFeature[org] = true;
    }

    /// @dev Method to Disable All
    function disableDenyHelper(address org)
        external
        override
        OrgRegistered(org)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        allowFeature[org] = false;
        denyFeature[org] = false;
    }

    // List of Helpers

    function getOrg(address _org)
        public
        view
        OrgRegistered(_org)
        returns (string memory, address, address, address[] memory, address)
    {
        return (
            orgs[_org].name,
            orgs[_org].lead,
            orgs[_org].safe,
            orgs[_org].child,
            orgs[_org].superSafe
        );
    }

    /// @notice update parent of a group
    /// @dev Update the parent of a group with a new parent, Call must come from the root safe
    /// @param group address of the group to be updated
    /// @param newSuper address of the new parent
    function updateSuper(address group, address newSuper)
        public
        GroupRegistered(_msgSender(), group)
        GroupRegistered(_msgSender(), newSuper)
        requiresAuth
    {
        address caller = _msgSender();
        Group storage _group = groups[caller][group];
        // SuperSafe is either an Org or a Group
        Group storage oldSuper;
        if (_group.superSafe == caller) {
            oldSuper = orgs[caller];
        } else {
            oldSuper = groups[caller][_group.superSafe];
        }

        /// Remove child from superSafe
        for (uint256 i = 0; i < oldSuper.child.length; i++) {
            if (oldSuper.child[i] == group) {
                oldSuper.child[i] = oldSuper.child[oldSuper.child.length - 1];
                oldSuper.child.pop();
                break;
            }
        }
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        // Revoke SuperSafe and SafeLead if don't have any child, and is not organization
        if ((oldSuper.child.length == 0) && (oldSuper.safe != caller)) {
            authority.setUserRole(oldSuper.safe, uint8(Role.SUPER_SAFE), false);
            // TODO: verify if the oldSuper need or not the Safe Lead role (after MVP)
        }

        // Update group superSafe
        _group.superSafe = newSuper;
        // Add group to new superSafe
        if (newSuper == caller) {
            orgs[caller].child.push(group);
        } else {
            /// Give Role SuperSafe if not have it
            if (!authority.doesUserHaveRole(newSuper, uint8(Role.SUPER_SAFE))) {
                authority.setUserRole(newSuper, uint8(Role.SUPER_SAFE), true);
            }
            groups[caller][newSuper].child.push(group);
        }
        emit GroupSuperUpdated(caller, group, caller, newSuper);
    }

    /// @notice Get all the information about a group
    function getGroupInfo(address org, address group)
        public
        view
        OrgRegistered(org)
        GroupRegistered(org, group)
        returns (string memory, address, address, address[] memory, address)
    {
        return (
            groups[org][group].name,
            groups[org][group].lead,
            groups[org][group].safe,
            groups[org][group].child,
            groups[org][group].superSafe
        );
    }

    /// @notice check if the organization is registered
    /// @param org address
    function isOrgRegistered(address org) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        return true;
    }

    /// @notice Check if child address is part of the group within an organization
    function isChild(address org, address superSafe, address child)
        public
        view
        returns (bool)
    {
        /// Check within orgs first if superSafe is an organization
        if (org == superSafe) {
            Group memory organization = orgs[org];
            for (uint256 i = 0; i < organization.child.length; i++) {
                if (organization.child[i] == child) return true;
            }
            return false;
        }
        /// Check within groups of the org
        Group memory group = groups[org][superSafe];
        if (group.safe == address(0)) {
            return false;
        }
        for (uint256 i = 0; i < group.child.length; i++) {
            if (group.child[i] == child) return true;
        }
        return false;
    }

    /// @notice Check if a user is an safe lead of a group/org
    /// @param org address of the organization
    /// @param group address of the group
    /// @param user address of the user that is a lead or not
    function isSafeLead(address org, address group, address user)
        public
        view
        returns (bool)
    {
        Group memory _group = (org == group) ? orgs[org] : groups[org][group];
        if (_group.safe == address(0)) return false;
        if (_group.lead == user) {
            return true;
        }
        return false;
    }

    /// @notice Check if the group is a superSafe of another group
    /// @param org address of the organization
    /// @param superSafe address of the superSafe
    /// @param child address of the child group
    function isSuperSafe(address org, address superSafe, address child)
        public
        view
        returns (bool)
    {
        Group memory childGroup = groups[org][child];
        address curentsuperSafe = childGroup.superSafe;
        /// TODO: probably more efficient to just create a superSafes mapping instead of this iterations
        while (curentsuperSafe != address(0)) {
            if (curentsuperSafe == superSafe) return true;
            childGroup = groups[org][curentsuperSafe];
            curentsuperSafe = childGroup.superSafe;
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

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this)
        );
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
        address org,
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
                org,
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
        address org,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(
            encodeTransactionData(org, safe, to, value, data, operation, _nonce)
        );
    }

    /// @notice disable safe lead roles
    /// @dev Associated roles: SAFE_LEAD || SAFE_LEAD_EXEC_ON_BEHALF_ONLY || SAFE_LEAD_MODIFY_OWNERS_ONLY
    /// @param user Address of the user to disable roles
    function disableSafeLeadRoles(address user) private {
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        if (authority.doesUserHaveRole(user, uint8(Role.SAFE_LEAD))) {
            authority.setUserRole(user, uint8(Role.SUPER_SAFE), false);
        } else if (
            authority.doesUserHaveRole(
                user, uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            )
        ) {
            authority.setUserRole(
                user, uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY), false
            );
        } else if (
            authority.doesUserHaveRole(
                user, uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            )
        ) {
            authority.setUserRole(
                user, uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY), false
            );
        }
    }

    /// @notice Check if the signer is an owner of the safe
    /// @dev Call has to be done from a safe transaction
    /// @param gnosisSafe GnosisSafe interface
    /// @param signer Address of the signer to verify
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
}
