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
    error ParentNotRegistered();

    struct Group {
        string name;
        address admin;
        address safe;
        mapping(address => bool) childs;
        address parent;
    }

    function getOrg(address _org) view public returns (string memory, address, address, address) {
        require(_org != address(0));
        require(orgs[_org].safe != address(0), "org not registered");
        return (orgs[_org].name, orgs[_org].admin, orgs[_org].safe, orgs[_org].parent);
    }

    function createOrg(string memory _name) public {
        Group storage rootOrg = orgs[msg.sender];
        rootOrg.admin = msg.sender;
        rootOrg.name = _name;
        rootOrg.safe = msg.sender;
    }

    // TODO only admin can add a group
    function addGroup(address _org, address _parent, address _admin, string memory _name) public {
        address orgSafe = orgs[_org].safe;
        if (orgSafe == address(0)) revert OrgNotRegistered();
        address parent = orgs[_parent].safe;
        if (parent == address(0)) {
            // Check within groups
            address parentGroup = groups[_org][_parent].safe;
            if (parentGroup == address(0)) revert ParentNotRegistered();
        }
        // TODO Add check for admin exist => Admin can only be an org?
        // require(groups[_org][_admin].safe != address(0), "admin group must be registered within org");
        Group storage group = groups[_org][msg.sender];
        group.name = _name;
        group.admin = _admin;
        group.parent = _parent;
        // TODO check if the sender will always be the safe or can be the admin
        group.safe = msg.sender;
    }

    function getGroupInfo(address _org, address _group) view public returns (string memory, address, address, address) {
        address groupSafe = groups[_org][_group].safe;
        require(groupSafe != address(0), "group not registered");
        return (groups[_org][_group].name, groups[_org][_group].admin, groups[_org][_group].safe, groups[_org][_group].parent);
    }

    function addChild(address _org, address _group, address _child) private {
        require(groups[_org][msg.sender].safe != address(0), "org must be registered");
        Group storage group = groups[_org][_group];
        group.childs[_child]=true;
    }
}
