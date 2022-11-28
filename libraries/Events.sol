// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

library Events {
    /// @dev Events
    event OrganizationCreated(
        address indexed creator,
        bytes32 indexed org,
        string name
    );

    /// @dev Event Fire when create a New Group (Tier 0) into the organization
    /// @param org Hash(DAO's name)
    /// @param groupCreated ID of the group
    /// @param lead Address of Safe Lead of the group
    /// @param creator Address of the creator of the group
    /// @param superSafe ID of Superior Group
    /// @param name String name of the group
    event GroupCreated(
        bytes32 indexed org,
        uint256 indexed groupCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when remove a Group (Tier 0) from the organization
    /// @param org Hash(DAO's name)
    /// @param groupRemoved ID of the group removed
    /// @param lead Address of Safe Lead of the group
    /// @param remover Address of the creator of the group
    /// @param superSafe ID of Superior Group
    /// @param name String name of the group
    event GroupRemoved(
        bytes32 indexed org,
        uint256 indexed groupRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Group (Tier 0) from the organization
    /// @param org Hash(DAO's name)
    /// @param groupUpdated ID of the group updated
    /// @param lead Address of Safe Lead of the group
    /// @param updater Address of the updater of the group
    /// @param oldSuperSafe ID of old Super Safe Group
    /// @param newSuperSafe ID of new Super Safe Group
    event GroupSuperUpdated(
        bytes32 indexed org,
        uint256 indexed groupUpdated,
        address lead,
        address indexed updater,
        uint256 oldSuperSafe,
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

    /// @dev Events Deny Helpers
    event AddedToList(address[] users);
    event DroppedFromList(address indexed user);

    /// @dev Event when a new keyperModule is setting up
    event KeyperModuleSetup(address keyperModule, address caller);
}
