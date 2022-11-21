// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Constants} from "./Constants.sol";
import {DenyHelper, Address} from "./DenyHelper.sol";
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
	/// @dev Enum Types
	enum Kinds {
		GROUP, // 0
		ROOT // 1
	}
    /// @devStruct for Group
	/// @param kind Kind of the group (at the momento only GROUP or ROOT)
	/// @param name String name of the group (any kind of group)
	/// @param lead Address of Safe Lead of the group (Safe Lead Role)
	/// @param safe Address of Safe of the group (Safe Role)
	/// @param child Array of ID's members of the group
	/// @param superSafe ID of Superior Group (superSafe Role)
    struct Group {
		Kinds kind;
        string name;
        address lead;
        address safe;
        uint256[] child;
        uint256 superSafe;
    }
	/// @dev index of the group
    uint256 public index;
    /// @dev Index of Group
	/// @dev Ens name -> ID's Groups
    mapping(bytes32 => uint256[]) public indexGroup;
    /// @dev Ens name -> Groups
    /// bytes32: ens_hashed.   uint256:GroupId.   Group: Group Info
    mapping(bytes32 => mapping(uint256 => Group)) public groups;

    /// @dev Events
    event OrganizationCreated(
        address indexed creator,
        uint256 indexed org,
        string name
    );

    event GroupCreated(
        uint256 indexed org,
        uint256 indexed group,
        address admin,
        address indexed caller,
        address superSafe,
        string name
    );

    event GroupRemoved(
        uint256 indexed org,
        uint256 indexed groupRemoved,
        address indexed caller,
        address superSafe,
        string name
    );

    event GroupSuperUpdated(
        uint256 indexed org,
        uint256 indexed oldGroup,
        address indexed caller,
        uint256 newSuperSafe
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
	error EmptyOrgName();
	error OrgAlreadyRegistered();

    /// @dev Modifier for Validate if Org Exist or Not
    modifier OrgRegistered(string calldata org) {
        if (!isOrgRegistered(org)) {
            revert OrgNotRegistered();
        }
        _;
    }

    /// @dev Modifier for Validate if Org/Group Exist or SuperSafeNotRegistered Not
    modifier GroupRegistered(string memory org, uint256 group) {
        if (groups[org][group].safe == address(0)) {
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
        string calldata org,
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
        if (isSafe(caller)) {
            // Check caller is a lead or superSafe of the target safe
            if (
                isSafeLead(org, targetSafe, caller)
                    || isSuperSafe(org, caller, targetSafe)
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
            if (!isSafeLead(org, targetSafe, caller)) {
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
        address owner,
        uint256 threshold,
        address targetSafe,
        string calldata org
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
        string calldata org
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
    /// @param user User that will have specific role // TODO: validate ir this user can be a Safe or EOAs
    /// @param group Safe group which will have the user permissions on
    function setRole(Role role, address user, string calldata org,uint256 group, bool enabled)
        external
		OrgRegistered(org)
		GroupRegistered(org,group)
        validAddress(user)
        requiresAuth
    {
		RolesAuthority authority = RolesAuthority(rolesAuthority);
		// TODO: validate if is or not redundant with modifier (requieresAuth)
        if ((groups[org][getGroupIdBySafe(org,_msgSender())].kind != Kinds.ROOT ) && (role == Role.ROOT_SAFE || role == Role.SUPER_SAFE)) {
            revert SetRoleForbidden(role);
        } else if ((groups[org][getGroupIdBySafe(org,_msgSender())].kind == Kinds.ROOT ) && (role == Role.ROOT_SAFE)) {
			groups[org][group].kind = Kinds.ROOT;
			// TODO: validate if is or not redundant role assign
			authority.setUserRole(user, uint8(Role.SUPER_SAFE), enabled);
        } else if (
            role == Role.SAFE_LEAD || role == Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY
                || role == Role.SAFE_LEAD_MODIFY_OWNERS_ONLY
        ) {
            // Update group/org lead
            groups[org][group].lead = user;
        }
        authority.setUserRole(user, uint8(role), enabled);
    }

    /// @notice Register an organization
    /// @dev Call has to be done from a safe transaction
    /// @param _name String with of the org (This name will be hashed into smart contract)
    function registerOrg(string calldata _name)
        external
        IsGnosisSafe(_msgSender())
    {
		if (_name.length == 0) {
			revert EmptyOrgName();
		}
		bytes32 name = bytes32(keccak256(abi.encodePacked(_name)));
		if (isOrgRegistered(name)) {
			revert OrgAlreadyRegistered();
		}
        address caller = _msgSender();
		// when register an org, need to create the first root safe group
        groups[name][index] = Group({
			kind: Kinds.ROOT,
			name: _name,
			lead: caller,
			safe: caller
		});
		indexGroup[name].push(index);
		index++;


        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(caller, uint8(Role.ROOT_SAFE), true);
        authority.setUserRole(caller, uint8(Role.SUPER_SAFE), true);

        emit OrganizationCreated(caller, name, _name);
    }

    /// @notice Add a group to an organization/group
    /// @dev Call coming from the group safe
    /// @param org address of the organization
    /// @param superSafe address of the superSafe
    /// @param name name of the group
    /// TODO: how avoid any safe adding in the org or group?
    function addGroup(string calldata org, uint256 superSafe, string memory name)
        external
        OrgRegistered(org)
        validAddress(superSafe)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        if (isChild(org, superSafe, caller)) revert ChildAlreadyExist();
        if (groups[org][superSafe].safe == address(0)) {
            revert GroupNotRegistered(superSafe);
        }
        Group storage newGroup = groups[org][caller];
        /// Add to org root/group
        Group storage superSafeOrgGroup = groups[org][superSafe];
		/// Add child to superSafe
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
    function removeGroup(string calldata org, uint256 group)
        external
        OrgRegistered(org)
        GroupRegistered(org, group)
        IsGnosisSafe(_msgSender())
        requiresAuth
    {
        address caller = _msgSender();
        // RootSafe usecase : Check if the group is part of caller's org
		if (groups[org][getGroupIdBySafe(org, caller)].safe == address(0)) {
			revert NotAuthorizedRemoveGroupFromOtherOrg();
		}
		// SuperSafe usecase : Check caller is superSafe of the group
		if (!isSuperSafe(org, getGroupIdBySafe(org, caller), group)) {
			revert NotAuthorizedRemoveNonChildrenGroup();
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
    /// @dev Method for getting all info of a group
    /// @param org uint256 of the organization
    /// @param group uint256 of the group
    function getGroupInfo(uint256 org, uint256 group)
        public
        view
        OrgRegistered(org)
        GroupRegistered(org, group)
        returns (
            string memory,
            address,
            address,
            uint256[] memory,
            uint256
        )
    {
        return (
            groups[org][group].name,
            groups[org][group].lead,
            groups[org][group].safe,
            groups[org][group].child,
            groups[org][group].superSafe
        );
    }

    /// @notice check if the organisation is registered
    /// @param org address
    function isOrgRegistered(string calldata org) public view returns (bool) {
        if (groups[org][indexGroup[org][0]].safe == address(0)) return false;
        return true;
    }

    /// @notice Check if child address is part of the group within an organization
    /// @param org uint256 of the organization
    /// @param superSafe uint256 of the superSafe
    /// @param child address of the child
    function isChild(
        string calldata org,
        uint256 superSafe,
        address child
    ) public view returns (bool) {
        /// Check within orgs first if superSafe is an organisation
        if (!isOrgRegistered(org)) return false;
        /// Check within groups of the org
        if (groups[org][superSafe].safe == address(0)) {
            revert SuperSafeNotRegistered();
        }
        Group memory group = groups[org][superSafe];
        for (uint256 i = 0; i < group.child.length; i++) {
            if (group.child[i] == getGroupIdBySafe(org, child)) return true;
        }
        return false;
    }

    /// @notice Check if the group is a superSafe of another group
    /// @param org uint256 of the organization
    /// @param superSafe uint256 of the superSafe
    /// @param child uint256 of the child
    function isSuperSafe(
        string calldata org,
        uint256 superSafe,
        uint256 child
    ) public view returns (bool) {
        return groups[org][child].superSafe == superSafe;
    }

    /// @dev Method to get Group ID by safe address
    /// @param org uint256 index of Organization
    /// @param safe Safe address
    /// @return Group ID
    function getGroupIdBySafe(uint256 org, address safe)
        public
        view
        OrgRegistered(org)
        returns (uint256)
    {
        /// Check if the Safe address is into an Org mapping
        if (safe == orgs[org].safe) return org;
        /// Check if the Safe address is into an Group mapping
        for (uint256 i = 0; i < indexGroup[org].length; i++) {
            if (groups[org][indexGroup[org][i]].safe == safe)
                return indexGroup[org][i];
        }
        return 0;
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

	/// @notice Private method to remove index from mapping of indexes into organizations
    /// @param org uint256 of the organization
    /// @param group uint256 of the group
    function removeIndexGroup(string calldata org, uint256 group) private {
        for (uint256 i = 0; i < indexGroup[org].length; i++) {
            if (indexGroup[org][i] == group) {
                indexGroup[org][i] = indexGroup[org][
                    indexGroup[org].length - 1
                ];
                indexGroup[org].pop();
                break;
            }
        }
    }
}
