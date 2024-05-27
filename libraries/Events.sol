// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

/// @title Library Events
/// @custom:security-contact general@palmeradao.xyz
library Events {
    /// @dev Event Fire when create a new Organisation
    /// @param creator Address of the creator
    /// @param org Hash(on-chain Organisation)
    /// @param name String name of the organisation
    event OrganisationCreated(
        address indexed creator,
        bytes32 indexed org,
        string name
    );

    /// @dev Event Fire when create a New Squad (Tier 0) into the organisation
    /// @param org Hash(on-chain Organisation)
    /// @param squadCreated ID of the squad
    /// @param lead Address of Safe Lead of the squad
    /// @param creator Address of the creator of the squad
    /// @param superSafe ID of Superior Squad
    /// @param name String name of the squad
    event SquadCreated(
        bytes32 indexed org,
        uint256 indexed squadCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when remove a Squad (Tier 0) from the organisation
    /// @param org Hash(on-chain Organisation)
    /// @param squadRemoved ID of the squad removed
    /// @param lead Address of Safe Lead of the squad
    /// @param remover Address of the creator of the squad
    /// @param superSafe ID of Superior Squad
    /// @param name String name of the squad
    event SquadRemoved(
        bytes32 indexed org,
        uint256 indexed squadRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Squad (Tier 0) from the organisation
    /// @param org Hash(on-chain Organisation)
    /// @param squadUpdated ID of the squad updated
    /// @param lead Address of Safe Lead of the squad
    /// @param updater Address of the updater of the squad
    /// @param oldSuperSafe ID of old Super Safe Squad
    /// @param newSuperSafe ID of new Super Safe Squad
    event SquadSuperUpdated(
        bytes32 indexed org,
        uint256 indexed squadUpdated,
        address lead,
        address indexed updater,
        uint256 oldSuperSafe,
        uint256 newSuperSafe
    );

    /// @dev Event Fire when Palmera Module execute a transaction on behalf of a Safe
    /// @param org Hash(on-chain Organisation)
    /// @param executor Address of the executor
    /// @param target Address of the Target Safe
    /// @param result Result of the execution of transaction on behalf of the Safe (true or false)
    event TxOnBehalfExecuted(
        bytes32 indexed org,
        address indexed executor,
        address superSafe,
        address indexed target,
        bool result
    );

    /// @dev Event Fire when any Safe enable the Palmera Module
    event ModuleEnabled(address indexed safe, address indexed module);

    /// @dev Event Fire when any Root Safe create a new Root Safe
    /// @param org Hash(on-chain Organisation)
    /// @param newIdRootSafeSquad New ID of the Root Safe Squad
    /// @param creator Address of the creator
    /// @param newRootSafeSquad Address of the new Root Safe
    /// @param name String name of the new Root Safe
    event RootSafeSquadCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeSquad,
        address indexed creator,
        address newRootSafeSquad,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Squad To Root Safe
    /// @param org Hash(on-chain Organisation)
    /// @param newIdRootSafeSquad ID of the squad updated
    /// @param updater Address of the updater of the squad
    /// @param newRootSafeSquad Address of the new Root Safe
    /// @param name String name of the new Root Safe
    event RootSafePromoted(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeSquad,
        address indexed updater,
        address newRootSafeSquad,
        string name
    );

    /// @dev Event Fire when an Root Safe Remove Whole of Tree
    /// @param org Hash(on-chain Organisation)
    /// @param rootSafeSquadId ID of the squad updated
    /// @param remover Address of the remover of the squad
    /// @param name String name of the new Root Safe
    event WholeTreeRemoved(
        bytes32 indexed org,
        uint256 indexed rootSafeSquadId,
        address indexed remover,
        string name
    );

    /// @dev Event Fire when any Root Safe change Depth Tree Limit
    /// @param org Hash(on-chain Organisation)
    /// @param rootSafeSquadId New ID of the Root Safe Squad
    /// @param updater Address of the Root Safe
    /// @param oldLimit uint256 Old Limit of Tree
    /// @param newLimit uint256 New Limit of Tree
    event NewLimitLevel(
        bytes32 indexed org,
        uint256 indexed rootSafeSquadId,
        address indexed updater,
        uint256 oldLimit,
        uint256 newLimit
    );

    /// @dev Event Fire when remove a Squad (Tier 0) from the organisation
    /// @param org Hash(on-chain Organisation)
    /// @param squad ID of the squad Disconnect
    /// @param safe Address of Safe Address of the squad Disconnect
    /// @param disconnector Address of the disconnector
    event SafeDisconnected(
        bytes32 indexed org,
        uint256 indexed squad,
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

    /// @dev Event when a new palmeraModule is setting up
    /// @param palmeraModule Address of the new palmeraModule
    /// @param caller Address of the deployer
    event PalmeraModuleSetup(address palmeraModule, address caller);
}
