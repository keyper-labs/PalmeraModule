// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.13;

import "./Enum.sol";
import {console} from "forge-std/console.sol";

interface GnosisSafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success);

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param to Destination address of Safe transaction.
    /// @param value Ether value of Safe transaction.
    /// @param data Data payload of Safe transaction.
    /// @param operation Operation type of Safe transaction.
    /// @param safeTxGas Gas that should be used for the Safe transaction.
    /// @param baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
    /// @param gasPrice Gas price that should be used for the payment calculation.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
}

// TODO modifiers for auth calling the diff functions
// TODO define how secure this setup should be: Calls only from Admin? Calls from safe contract (with multisig rule)
// TODO update signers set
contract KeyperModule {
    string public constant NAME = "Keyper Module";
    string public constant VERSION = "0.1.0";

    // Orgs -> Groups
    mapping(address => mapping(address => Group)) public groups;
    // Safe -> full set of signers
    mapping(address => mapping(address => bool)) public signers;

    // Orgs info
    mapping(address => Group) public orgs;

    // Errors
    error OrgNotRegistered();
    error GroupNotRegistered();
    error ParentNotRegistered();
    error AdminNotRegistered();
    error NotAuthorized();

    struct Group {
        string name;
        address admin;
        address safe;
        mapping(address => bool) childs;
        address parent;
    }

    struct TransactionHelper {
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
    }

    modifier onlyAdmin(address _group) {
        require(_group != address(0));
        if (orgs[msg.sender].safe == address(0)) revert AdminNotRegistered();
        Group storage group = groups[msg.sender][_group];
        // if (msg.sender != group.admin) revert NotAuthorized();
        // TODO ADD case when adding a group that has not been set his admin
        // In this case we should just check that the Admin is an org
        // Add later check on addGroup function that will reverify the correct org is the admin
        _;
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

    function createOrg(string memory _name) public {
        Group storage rootOrg = orgs[msg.sender];
        rootOrg.admin = msg.sender;
        rootOrg.name = _name;
        rootOrg.safe = msg.sender;
    }

    // TODO call auth modifier (only admin can add a group)
    // Org to add group
    // group safe address
    // Parent: Registered org or group
    // Admin: Registered org
    // Group name
    function addGroup(
        address _org,
        address _group,
        address _parent,
        address _admin,
        string memory _name
    ) public {
        if (orgs[_org].safe == address(0)) revert OrgNotRegistered();
        if (orgs[_parent].safe == address(0)) {
            // Check within groups
            if (groups[_org][_parent].safe == address(0))
                revert ParentNotRegistered();
        }
        if (orgs[_admin].safe == address(0)) revert AdminNotRegistered();
        // check msg.sender is the admin of the _org
        if (msg.sender != _org) revert NotAuthorized();
        Group storage group = groups[_org][_group];
        group.name = _name;
        group.admin = _admin;
        group.parent = _parent;
        group.safe = _group;
        // Update child on parent
        // TODO add logic to handle childs for orgs
        Group storage parentGroup = groups[_org][_parent];
        parentGroup.childs[_group] = true;
        // Is parent an org? => need to update the org mapping info too
        if (_org == _parent) {
            Group storage org = orgs[_org];
            org.childs[_group] = true;
        }
    }

    // returns
    // name Group
    // admin @
    // safe @
    // parent @
    function getGroupInfo(address _org, address _group)
        public
        view
        returns (
            string memory,
            address,
            address,
            address
        )
    {
        address groupSafe = groups[_org][_group].safe;
        if (groupSafe == address(0)) revert OrgNotRegistered();

        return (
            groups[_org][_group].name,
            groups[_org][_group].admin,
            groups[_org][_group].safe,
            groups[_org][_group].parent
        );
    }

    // Check if _child address is part of the group
    function isChild(
        address _org,
        address _parent,
        address _child
    ) public view returns (bool) {
        if (orgs[_org].safe == address(0)) revert OrgNotRegistered();
        // Check within orgs first if parent is org
        if (_org == _parent) {
            Group storage org = orgs[_org];
            return org.childs[_child];
        }
        // Check within groups of the org
        if (groups[_org][_parent].safe == address(0))
            revert ParentNotRegistered();
        Group storage group = groups[_org][_parent];
        return group.childs[_child];
    }

    // TODO: Check if we need to implement this function for the demo
    // function associateChild(address _org, address _group, address _child) private
    function execKeeperTransaction(
        address _org,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        TransactionHelper calldata txHelper,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success) {
        // TODO Remove this dummy logic
        // if (orgs[_org].safe == address(0)) revert OrgNotRegistered();
        // check msg.sender is the admin of the _org
        if (msg.sender != _org) revert NotAuthorized();

        // Init gnosis safe contract
        GnosisSafe gnosisSafe = GnosisSafe(safe);
        return
            gnosisSafe.execTransaction(
                to,
                value,
                data,
                txHelper.operation,
                txHelper.safeTxGas,
                txHelper.baseGas,
                txHelper.gasPrice,
                txHelper.gasToken,
                refundReceiver,
                signatures
            );
    }
}
