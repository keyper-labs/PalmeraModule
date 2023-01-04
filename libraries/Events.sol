// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

/// @title Library Events
/// @custom:security-contact general@palmeradao.xyz
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

    /// @dev Event Fire when Keyper Module execute a transaction on behalf of a Safe
    /// @param org Hash(DAO's name)
    /// @param executor Address of the executor
    /// @param target Address of the Target Safe
    /// @param result Result of the execution of transaction on behalf of the Safe (true or false)
    event TxOnBehalfExecuted(
        bytes32 indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    /// @dev Event Fire when any Gnosis Safe enable the Keyper Module
    event ModuleEnabled(address indexed safe, address indexed module);

    /// @dev Event Fire when any Root Safe create a new Root Safe
    /// @param org Hash(DAO's name)
    /// @param newIdRootSafeGroup New ID of the Root Safe Group
    /// @param creator Address of the creator
    /// @param newRootSafeGroup Address of the new Root Safe
    /// @param name String name of the new Root Safe
    event RootSafeGroupCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeGroup,
        address indexed creator,
        address newRootSafeGroup,
        string name
    );

    /// @dev Event Fire when any Root Safe change Depth Tree Limit
    /// @param org Hash(DAO's name)
    /// @param rootSafeGroupId New ID of the Root Safe Group
    /// @param updater Address of the Root Safe
    /// @param oldLimit uint256 Old Limit of Tree
    /// @param newLimit uint256 New Limit of Tree
    event NewLimitLevel(
        bytes32 indexed org,
        uint256 indexed rootSafeGroupId,
        address indexed updater,
        uint256 oldLimit,
        uint256 newLimit
    );

	/// @dev Event Fire when remove a Group (Tier 0) from the organization
    /// @param org Hash(DAO's name)
    /// @param group ID of the group Disconnect
	/// @param safe Address of Safe Address of the group Disconnect
	/// @param disconnector Address of the disconnector
    event SafeDisconnected(
        bytes32 indexed org,
        uint256 indexed group,
        address indexed safe,
        address disconnector
    );

    /// @notice Events Deny Helpers

    /// @dev Event Fire when add several wallet into the deny/allow list
    /// @param users Array of wallets
    event AddedToList(address[] users);

    /// @dev Event Fire when drop a wallet into the deny/allow list
    /// @param user Wallet to drop of the deny/allow list
    event DroppedFromList(address indexed user);

    /// @dev Event when a new keyperModule is setting up
    /// @param keyperModule Address of the new keyperModule
    /// @param caller Address of the deployer
    event KeyperModuleSetup(address keyperModule, address caller);
}
