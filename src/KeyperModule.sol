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

contract KeyperModule is Auth, Constants, DenyHelper {
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
        address admin;
        address safe;
        address[] child;
        address parent;
    }
    /// @dev Orgs -> Groups

    mapping(address => mapping(address => Group)) public groups;
    /// @dev Orgs info
    mapping(address => Group) public orgs;
    /// @dev Events

    event OrganisationCreated(address indexed org, string name);

    event GroupCreated(
        address indexed org,
        address indexed group,
        string name,
        address indexed admin,
        address parent
    );

    event GroupRemoved(
        address indexed org,
        address indexed groupRemoved,
        address indexed caller,
        address parent,
        string name
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
    error GroupNotRegistered();
    error ParentNotRegistered();
    error AdminNotRegistered();
    error NotAuthorized();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedAsNotAnAdmin();
    error OwnerNotFound();
    error OwnerAlreadyExists();
    error CreateSafeProxyFailed();
    error InvalidThreshold();
    error TxExecutionModuleFaild();
    error ChildAlreadyExist();
    error InvalidGnosisSafe();
    error ChildNotFound();

    /// @dev Modifier for Validate if Org Exist or Not
    modifier OrgRegistered(address org) {
        if (org == address(0) || orgs[org].safe == address(0)) {
            revert OrgNotRegistered();
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

        // if (
        //     !masterCopyAddress.isContract() || !proxyFactoryAddress.isContract()
        // ) revert InvalidAddressProvided();

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
    ) external payable Denied(to) returns (bool result) {
        if (org == address(0) || targetSafe == address(0) || to == address(0)) {
            revert ZeroAddressProvided();
        }
        if (!isSafe(targetSafe)) {
            revert InvalidGnosisSafe();
        }
        address caller = _msgSender();
        /// Check caller is an admin of the target safe
        if (!isAdmin(caller, targetSafe) && !isParent(org, caller, targetSafe))
        {
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
        /// TODO not sure about caller => Maybe just check admin address

        /// Init safe interface to get parent owners/threshold
        IGnosisSafe gnosisAdminSafe = IGnosisSafe(caller);
        gnosisAdminSafe.checkSignatures(
            keccak256(keyperTxHashData), keyperTxHashData, signatures
        );
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

    /// @notice This function will allow UserAdmin to add owner and set a threshold without passing by normal multisig check
    /// @dev For instance role
    function addOwnerWithThreshold(
        address owner,
        uint256 threshold,
        address targetSafe
    ) public requiresAuth Denied(owner) IsGnosisSafe(targetSafe) {
        /// Check _msgSender() is an user admin of the target safe
        if (!isUserAdmin(targetSafe, _msgSender())) {
            revert NotAuthorizedAsNotAnAdmin();
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

    /// @notice This function will allow UserAdmin to remove an owner
    /// @dev For instance role
    function removeOwner(
        address prevOwner,
        address owner,
        uint256 threshold,
        address targetSafe
    ) public requiresAuth IsGnosisSafe(targetSafe) {
        /// Check _msgSender() is an user admin of the target safe
        if (!isUserAdmin(targetSafe, _msgSender())) {
            revert NotAuthorizedAsNotAnAdmin();
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

    /// @notice Give user admin role
    /// @dev Call must come from the safe
    /// @param user User that will have the Admin role
    function setUserAdmin(address user, bool enabled)
        external
        validAddress(user)
        requiresAuth
    {
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(user, ADMIN_ADD_OWNERS_ROLE, enabled);
        authority.setUserRole(user, ADMIN_REMOVE_OWNERS_ROLE, enabled);
        /// Update user admin on org
        Group storage org = orgs[_msgSender()];
        org.admin = user;
    }

    function getOrg(address _org)
        public
        view
        OrgRegistered(_org)
        returns (string memory, address, address, address[] memory, address)
    {
        return (
            orgs[_org].name,
            orgs[_org].admin,
            orgs[_org].safe,
            orgs[_org].child,
            orgs[_org].parent
        );
    }

    /// @notice Register an organisatin
    /// @dev Call has to be done from a safe transaction
    /// @param name of the org
    function registerOrg(string memory name)
        public
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        Group storage rootOrg = orgs[caller];
        rootOrg.admin = caller;
        rootOrg.name = name;
        rootOrg.safe = caller;

        /// Set org role to set admin role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(caller, SAFE_SET_ROLE, true);

        authority.setRoleCapability(
            SAFE_SET_ROLE, address(this), SET_USER_ADMIN, true
        );

        emit OrganisationCreated(caller, name);
    }

    /// @notice Add a group to an organisation/group
    /// @dev Call coming from the group safe
    /// @param org address of the organisation
    /// @param parent address of the parent
    /// @param name name of the group
	/// TODO: how avoid any safe adding in the org or group?
    function addGroup(address org, address parent, string memory name)
        public
        OrgRegistered(org)
        validAddress(parent)
        Denied(parent)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        if (isChild(org, parent, caller)) revert ChildAlreadyExist();
        Group storage newGroup = groups[org][caller];
        /// Add to org root
        if (parent == org) {
            ///  By default Admin of the new group is the admin of the org
            newGroup.admin = orgs[org].admin;
            Group storage parentOrg = orgs[org];
            parentOrg.child.push(caller);
        }
        /// Add to group
        else {
            /// By default Admin of the new group is the admin of the parent (TODO check this)
            newGroup.admin = groups[org][parent].admin;
            Group storage parentGroup = groups[org][parent];
            parentGroup.child.push(caller);
        }
        newGroup.parent = parent;
        newGroup.safe = caller;
        newGroup.name = name;
        emit GroupCreated(org, caller, name, newGroup.admin, parent);
    }

    /// @notice Remove group and reasign all child to the parent
    /// @dev All actions will be driven based on the caller of the method, and args
    /// @param org address of the organisation
    /// @param group address of the group to be removed
    /// TODO: Add auth/permissions for the caller
    function removeGroup(address org, address group)
        public
        OrgRegistered(org)
        validAddress(group)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        Group memory _group = groups[org][group];
        if (_group.safe == address(0)) revert GroupNotRegistered();

        // Parent is either an org or a group
        Group storage parent =
            _group.parent == org ? orgs[org] : groups[org][_group.parent];

        /// Remove child from parent
        for (uint256 i = 0; i < parent.child.length; i++) {
            if (parent.child[i] == group) {
                parent.child[i] = parent.child[parent.child.length - 1];
                parent.child.pop();
                break;
            }
        }
        // Handle child from removed group
        for (uint256 i = 0; i < _group.child.length; i++) {
            // Add removed group child to parent
            parent.child.push(_group.child[i]);
            Group storage childrenGroup = groups[org][_group.child[i]];
            // Update children group parent reference
            childrenGroup.parent = parent.safe;
        }

        // Store the name before to delete the Group
        emit GroupRemoved(org, group, caller, parent.safe, _group.name);
        delete groups[org][group];
    }

    /// @notice Get all the information about a group
    function getGroupInfo(address org, address group)
        public
        view
        OrgRegistered(org)
        validAddress(group)
        returns (string memory, address, address, address[] memory, address)
    {
        address groupSafe = groups[org][group].safe;
        if (groupSafe == address(0)) revert OrgNotRegistered();
        return (
            groups[org][group].name,
            groups[org][group].admin,
            groups[org][group].safe,
            groups[org][group].child,
            groups[org][group].parent
        );
    }

    /// @notice check if the organisation is registered
    /// @param org address
    function isOrgRegistered(address org) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        return true;
    }

    /// @notice Check if child address is part of the group within an organisation
    function isChild(address org, address parent, address child)
        public
        view
        returns (bool)
    {
        /// Check within orgs first if parent is an organisation
        if (org == parent) {
            Group memory organisation = orgs[org];
            for (uint256 i = 0; i < organisation.child.length; i++) {
                if (organisation.child[i] == child) return true;
            }
            return false;
        }
        /// Check within groups of the org
        if (groups[org][parent].safe == address(0)) {
            revert ParentNotRegistered();
        }
        Group memory group = groups[org][parent];
        for (uint256 i = 0; i < group.child.length; i++) {
            if (group.child[i] == child) return true;
        }
        return false;
    }

    /// @notice Check if an org is admin of the group
    function isAdmin(address org, address group) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        /// Check group admin
        Group memory _group = groups[org][group];
        if (_group.admin == org) {
            return true;
        }
        return false;
    }

    /// @notice Check if a user is an admin of the org
    function isUserAdmin(address org, address user)
        public
        view
        returns (bool)
    {
        Group memory _org = orgs[org];
        if (_org.admin == user) {
            return true;
        }
        return false;
    }

    /// @notice Check if the group is a parent of another group
    function isParent(address org, address parent, address child)
        public
        view
        returns (bool)
    {
        Group memory childGroup = groups[org][child];
        address curentParent = childGroup.parent;
        /// TODO: probably more efficient to just create a parents mapping instead of this iterations
        while (curentParent != address(0)) {
            if (curentParent == parent) return true;
            childGroup = groups[org][curentParent];
            curentParent = childGroup.parent;
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
        /// solhint-disable-next-line no-inline-assembly
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

    /// @notice Check if the signer is an owner of the safe
    /// @dev Call has to be done from a safe transaction
    /// @param gnosisSafe GnosisSafe interface
    /// @param signer Address of the signer to verify
    function isSafeOwner(IGnosisSafe gnosisSafe, address signer)
        private
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
