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

    event OrganisationCreated(address indexed org, string name);

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
    error SuperSafeNotRegistered();
    error LeadNotRegistered();
    error NotAuthorized();
    error NotAuthorizedRemoveGroupFromOtherOrg();
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
    ) external payable Denied(to) requiresAuth returns (bool result) {
        if (org == address(0) || targetSafe == address(0) || to == address(0)) {
            revert ZeroAddressProvided();
        }
        if (!isSafe(targetSafe)) {
            revert InvalidGnosisSafe();
        }
        address caller = _msgSender();
        /// Check caller is an lead of the target safe
        if (
            !isLead(caller, targetSafe) && !isSuperSafe(org, caller, targetSafe)
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
        /// TODO not sure about caller => Maybe just check lead address
        // TODO add usecase for safe lead => Caller can be an EOA account,
        // so first we need to check if safe, if yes load gnosis interface + call owners...,
        // if not then just execute the tx after checking signature
        /// Init safe interface to get superSafe owners/threshold
        IGnosisSafe gnosisLeadSafe = IGnosisSafe(caller);
        gnosisLeadSafe.checkSignatures(
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

    /// @notice This function will allow Safe Lead & Safe Lead mody only roles to to add owner and set a threshold without passing by normal multisig check
    /// @dev For instance role
    /// TODO add modifier for check that targetSafe is a Safe / Check orgRegister
    function addOwnerWithThreshold(
        address owner,
        uint256 threshold,
        address targetSafe,
        address org
    ) public requiresAuth IsGnosisSafe(targetSafe) {
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
    ) public requiresAuth IsGnosisSafe(targetSafe) {
        if (
            prevOwner == address(0) || targetSafe == address(0)
                || owner == address(0) || org == address(0)
        ) revert ZeroAddressProvided();
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
        if (
            role == Role.SAFE_LEAD || role == Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY
                || role == Role.SAFE_LEAD_MODIFY_OWNERS_ONLY
        ) {
            /// Check if group is part of the org
            if (groups[_msgSender()][group].safe == address(0)) {
                revert SuperSafeNotRegistered();
            }
            /// Update group lead
            Group storage safeGroup = groups[_msgSender()][group];
            safeGroup.lead = user;
        }
        // TODO check other cases when we need to update org
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(user, uint8(role), enabled);
    }

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

    /// @notice Register an organisatin
    /// @dev Call has to be done from a safe transaction
    /// @param name of the org
    function registerOrg(string memory name)
        public
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        Group storage rootOrg = orgs[caller];
        rootOrg.lead = caller;
        rootOrg.name = name;
        rootOrg.safe = caller;

        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(caller, uint8(Role.ROOT_SAFE), true);
        authority.setUserRole(caller, uint8(Role.SUPER_SAFE), true);

        emit OrganisationCreated(caller, name);
    }

    /// @notice Add a group to an organisation/group
    /// @dev Call coming from the group safe
    /// @param org address of the organisation
    /// @param superSafe address of the superSafe
    /// @param name name of the group
    /// TODO: how avoid any safe adding in the org or group?
    function addGroup(address org, address superSafe, string memory name)
        public
        OrgRegistered(org)
        validAddress(superSafe)
        IsGnosisSafe(_msgSender())
    {
        address caller = _msgSender();
        if (isChild(org, superSafe, caller)) revert ChildAlreadyExist();
        Group storage newGroup = groups[org][caller];
        /// Add to org root
        if (superSafe == org) {
            ///  By default Lead of the new group is the lead of the org
            newGroup.lead = orgs[org].lead;
            Group storage superSafeOrg = orgs[org];
            superSafeOrg.child.push(caller);
        }
        /// Add to group
        else {
            /// By default Lead of the new group is the lead of the superSafe (TODO check this)
            newGroup.lead = groups[org][superSafe].lead;
            Group storage superSafeGroup = groups[org][superSafe];
            superSafeGroup.child.push(caller);
        }
        newGroup.superSafe = superSafe;
        newGroup.safe = caller;
        newGroup.name = name;
        /// Give Role SuperSafe
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(caller, uint8(Role.SUPER_SAFE), true);

        emit GroupCreated(org, caller, name, newGroup.lead, superSafe);
    }

    /// @notice Remove group and reasign all child to the superSafe
    /// @dev All actions will be driven based on the caller of the method, and args
    /// @param org address of the organisation
    /// @param group address of the group to be removed
    /// TODO: Add auth/permissions for the caller
    function removeGroup(address org, address group)
        public
        OrgRegistered(org)
        validAddress(group)
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
        if (_group.safe == address(0)) revert GroupNotRegistered();

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

        // Store the name before to delete the Group
        emit GroupRemoved(org, group, caller, superSafe.safe, _group.name);
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
            groups[org][group].lead,
            groups[org][group].safe,
            groups[org][group].child,
            groups[org][group].superSafe
        );
    }

    /// @notice check if the organisation is registered
    /// @param org address
    function isOrgRegistered(address org) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        return true;
    }

    /// @notice Check if child address is part of the group within an organisation
    function isChild(address org, address superSafe, address child)
        public
        view
        returns (bool)
    {
        /// Check within orgs first if superSafe is an organisation
        if (org == superSafe) {
            Group memory organisation = orgs[org];
            for (uint256 i = 0; i < organisation.child.length; i++) {
                if (organisation.child[i] == child) return true;
            }
            return false;
        }
        /// Check within groups of the org
        if (groups[org][superSafe].safe == address(0)) {
            revert SuperSafeNotRegistered();
        }
        Group memory group = groups[org][superSafe];
        for (uint256 i = 0; i < group.child.length; i++) {
            if (group.child[i] == child) return true;
        }
        return false;
    }

    /// @notice Check if an org is lead of the group
    function isLead(address org, address group) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        /// Check group lead
        Group memory _group = groups[org][group];
        if (_group.lead == org) {
            return true;
        }
        return false;
    }

    /// @notice Check if a user is an lead of the org
    /// TODO: This function is not used anymore, check if we need to delete it
    function isOrgLead(address org, address user) public view returns (bool) {
        Group memory _org = orgs[org];
        if (_org.lead == user) {
            return true;
        }
        return false;
    }

    /// @notice Check if a user is an safe lead of the group
    function isSafeLead(address org, address group, address user)
        public
        view
        returns (bool)
    {
        if (org == group) return false; // Root org cannot have a lead
        Group memory _group = groups[org][group];
        if (_group.safe == address(0)) revert GroupNotRegistered();
        if (_group.lead == user) {
            return true;
        }
        return false;
    }

    /// @notice Check if the group is a superSafe of another group
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
