// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Constants} from "./Constants.sol";
import {console} from "forge-std/console.sol";
import {KeyperRoles} from "./KeyperRoles.sol";

contract KeyperModule is Auth, Constants {
    string public constant NAME = "Keyper Module";
    string public constant VERSION = "0.2.0";

    // Safe contracts
    address public immutable masterCopy;
    address public immutable proxyFactory;

    // Orgs -> Groups
    mapping(address => mapping(address => Group)) public groups;

    // Orgs info
    mapping(address => Group) public orgs;

    uint256 public nonce;
    address internal constant SENTINEL_OWNERS = address(0x1);

    // RoleAuthority
    address public rolesAuthority;

    // Events
    event OrganisationCreated(address indexed org, string name);

    event GroupCreated(
        address indexed org,
        address indexed group,
        string name,
        address indexed admin,
        address parent
    );

    event TxOnBehalfExecuted(
        address indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    event ModuleEnabled(address indexed safe, address indexed module);

    // Errors
    error OrgNotRegistered();
    error GroupNotRegistered();
    error ParentNotRegistered();
    error AdminNotRegistered();
    error NotAuthorized();
    error NotAuthorizedExecOnBehalf();
    error CreateSafeProxyFailed();

    struct Group {
        string name;
        address admin;
        address safe;
        address[] childs;
        address parent;
    }

    struct TransactionHelper {
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
    }

    constructor(
        address masterCopyAddress,
        address proxyFactoryAddress,
        address authority
    ) Auth(address(0), Authority(authority)) {
        require(masterCopyAddress != address(0));
        require(proxyFactoryAddress != address(0));
        require(authority != address(0));

        masterCopy = masterCopyAddress;
        proxyFactory = proxyFactoryAddress;
        rolesAuthority = authority;
    }

    function createSafeProxy(address[] memory owners, uint256 threshold)
        external
        returns (address safe)
    {
        bytes memory internalEnableModuleData = abi.encodeWithSignature(
            "internalEnableModule(address)",
            address(this)
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

    function getOrg(address _org)
        public
        view
        returns (
            string memory,
            address,
            address,
            address
        )
    {
        require(_org != address(0));
        if (orgs[_org].safe == address(0)) revert OrgNotRegistered();
        return (
            orgs[_org].name,
            orgs[_org].admin,
            orgs[_org].safe,
            orgs[_org].parent
        );
    }

    /// @notice Register an organisatin
    /// @dev Call has to be done from a safe transaction
    /// @param name of the org
    function registerOrg(string memory name) public {
        // @TODO: Add check to verify call is coming from a safe
        Group storage rootOrg = orgs[msg.sender];
        rootOrg.admin = msg.sender;
        rootOrg.name = name;
        rootOrg.safe = msg.sender;

        // Set org role to set admin role
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(msg.sender, SAFE_SET_ROLE, true);

        authority.setRoleCapability(
            SAFE_SET_ROLE,
            address(this),
            SET_USER_ADMIN,
            true
        );

        emit OrganisationCreated(msg.sender, name);
    }

    /// @notice check if the organisation is registered
    /// @param org address
    function isOrgRegistered(address org) public view returns (bool) {
        if (orgs[org].safe == address(0)) {
            return false;
        }
        return true;
    }

    /// @notice Add a group to an organisation/group
    /// @dev Call coming from the group safe
    /// @param org address of the organisation
    /// @param parent address of the parent
    /// @param name name of the group
    function addGroup(
        address org,
        address parent,
        string memory name
    ) public {
        if (orgs[org].safe == address(0)) revert OrgNotRegistered();
        Group storage newGroup = groups[org][msg.sender];
        // Add to org root
        if (parent == org) {
            // By default Admin of the new group is the admin of the org
            newGroup.admin = orgs[org].admin;
            Group storage parentOrg = orgs[org];
            parentOrg.childs.push(msg.sender);
        }
        // Add to group
        else {
            if (groups[org][parent].safe == address(0))
                revert ParentNotRegistered();
            // By default Admin of the new group is the admin of the parent (TODO check this)
            newGroup.admin = groups[org][parent].admin;
            Group storage parentGroup = groups[org][parent];
            parentGroup.childs.push(msg.sender);
        }
        newGroup.parent = parent;
        newGroup.safe = msg.sender;
        newGroup.name = name;
        emit GroupCreated(org, msg.sender, name, newGroup.admin, parent);
    }

    /// @notice Get all the information about a group
    function getGroupInfo(address org, address group)
        public
        view
        returns (
            string memory,
            address,
            address,
            address
        )
    {
        address groupSafe = groups[org][group].safe;
        if (groupSafe == address(0)) revert OrgNotRegistered();

        return (
            groups[org][group].name,
            groups[org][group].admin,
            groups[org][group].safe,
            groups[org][group].parent
        );
    }

    /// @notice Check if child address is part of the group within an organisation
    function isChild(
        address org,
        address parent,
        address child
    ) public view returns (bool) {
        if (orgs[org].safe == address(0)) revert OrgNotRegistered();
        // Check within orgs first if parent is an organisation
        if (org == parent) {
            Group memory organisation = orgs[org];
            for (uint256 i = 0; i < organisation.childs.length; i++) {
                if (organisation.childs[i] == child) return true;
            }
        }
        // Check within groups of the org
        if (groups[org][parent].safe == address(0))
            revert ParentNotRegistered();
        Group memory group = groups[org][parent];
        for (uint256 i = 0; i < group.childs.length; i++) {
            if (group.childs[i] == child) return true;
        }
        return false;
    }

    /// @notice Check if an org is admin of the group
    function isAdmin(address org, address group) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        // Check group admin
        Group memory _group = groups[org][group];
        if (_group.admin == org) {
            return true;
        }
        return false;
    }

    /// @notice Check if the group is a parent of another group
    function isParent(
        address org,
        address parent,
        address child
    ) public view returns (bool) {
        Group memory childGroup = groups[org][child];
        address curentParent = childGroup.parent;
        // TODO: probably more efficient to just create a parents mapping instead of this iterations
        while (curentParent != address(0)) {
            if (curentParent == parent) return true;
            childGroup = groups[org][curentParent];
            curentParent = childGroup.parent;
        }
        return false;
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
    ) external payable returns (bool success) {
        // Check msg.sender is an admin of the target safe
        if (
            !isAdmin(msg.sender, targetSafe) &&
            !isParent(org, msg.sender, targetSafe)
        ) {
            // Check if it a then parent
            revert NotAuthorizedExecOnBehalf();
        }

        bytes32 txHash;
        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            bytes memory keyperTxHashData = encodeTransactionData(
                // Keyper Info
                msg.sender,
                targetSafe,
                // Transaction info
                to,
                value,
                data,
                operation,
                // Signature info
                nonce
            );
            // Increase nonce and execute transaction.
            nonce++;
            txHash = keccak256(keyperTxHashData);
            // TODO not sure about msg.sender => Maybe just check admin address
            // Init safe interface to get parent owners/threshold
            IGnosisSafe gnosisAdminSafe = IGnosisSafe(msg.sender);
            gnosisAdminSafe.checkSignatures(
                txHash,
                keyperTxHashData,
                signatures
            );
            // Execute transaction from target safe
            IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
            bool result = gnosisTargetSafe.execTransactionFromModule(
                to,
                value,
                data,
                operation
            );
            emit TxOnBehalfExecuted(org, msg.sender, targetSafe, result);
            return result;
        }
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
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
        return
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator(),
                keyperTxHash
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
        return
            keccak256(
                encodeTransactionData(
                    org,
                    safe,
                    to,
                    value,
                    data,
                    operation,
                    _nonce
                )
            );
    }

    function internalEnableModule(address module) external {
        this.enableModule(module);
    }

    // Non-executed code, function called by the new safe
    function enableModule(address module) external {
        emit ModuleEnabled(address(this), module);
    }

    // ROLES AUTH FUNCTIONS

    /// @notice Give user admin role
    /// @dev Call must come from the group safe
    /// @param user User that will have the Admin role
    function setUserAdmin(address user, bool enabled) public requiresAuth {
        RolesAuthority authority = RolesAuthority(rolesAuthority);
        authority.setUserRole(user, ADMIN_ADD_OWNERS_ROLE, enabled);
        authority.setUserRole(user, ADMIN_REMOVE_OWNERS_ROLE, enabled);
    }
}
