// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

/// @title Library Events
/// @custom:security-contact general@palmeradao.xyz
library Events {
    /// @dev Event Fire when create a new Organisation
    /// @param creator Address of the creator
    /// @param org Hash (On-chain Organisation)
    /// @param name String name of the organisation
    event OrganisationCreated(
        address indexed creator,
        bytes32 indexed org,
        string name
    );

    /// @dev Event Fire when create a New Safe (Tier 0) into the organisation
    /// @param org Hash (On-chain Organisation)
    /// @param safeCreated ID of the safe
    /// @param lead Address of Safe Lead of the safe
    /// @param creator Address of the creator of the safe
    /// @param superSafe ID of Superior Safe
    /// @param name String name of the safe
    event SafeCreated(
        bytes32 indexed org,
        uint256 indexed safeCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when remove a Safe (Tier 0) from the organisation
    /// @param org Hash (On-chain Organisation)
    /// @param safeRemoved ID of the safe removed
    /// @param lead Address of Safe Lead of the safe
    /// @param remover Address of the creator of the safe
    /// @param superSafe ID of Superior Safe
    /// @param name String name of the safe
    event SafeRemoved(
        bytes32 indexed org,
        uint256 indexed safeRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Safe (Tier 0) from the organisation
    /// @param org Hash (On-chain Organisation)
    /// @param safeUpdated ID of the safe updated
    /// @param lead Address of Safe Lead of the safe
    /// @param updater Address of the updater of the safe
    /// @param oldSuperSafe ID of old Super Safe
    /// @param newSuperSafe ID of new Super Safe
    event SafeSuperUpdated(
        bytes32 indexed org,
        uint256 indexed safeUpdated,
        address lead,
        address indexed updater,
        uint256 oldSuperSafe,
        uint256 newSuperSafe
    );

    /// @dev Event Fire when Palmera Module execute a transaction on behalf of a Safe
    /// @param org Hash (On-chain Organisation)
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
    /// @param org Hash (On-chain Organisation)
    /// @param newIdRootSafe New ID of the Root Safe
    /// @param creator Address of the creator
    /// @param newRootSafe Address of the new Root Safe
    /// @param name String name of the new Root Safe
    event RootSafeCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafe,
        address indexed creator,
        address newRootSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Safe To Root Safe
    /// @param org Hash (On-chain Organisation)
    /// @param newIdRootSafe ID of the safe updated
    /// @param updater Address of the updater of the safe
    /// @param newRootSafe Address of the new Root Safe
    /// @param name String name of the new Root Safe
    event RootSafePromoted(
        bytes32 indexed org,
        uint256 indexed newIdRootSafe,
        address indexed updater,
        address newRootSafe,
        string name
    );

    /// @dev Event Fire when an Root Safe Remove Whole of Tree
    /// @param org Hash (On-chain Organisation)
    /// @param rootSafeId ID of the safe updated
    /// @param remover Address of the remover of the safe
    /// @param name String name of the new Root Safe
    event WholeTreeRemoved(
        bytes32 indexed org,
        uint256 indexed rootSafeId,
        address indexed remover,
        string name
    );

    /// @dev Event Fire when any Root Safe change Depth Tree Limit
    /// @param org Hash (On-chain Organisation)
    /// @param rootSafeId New ID of the Root Safe
    /// @param updater Address of the Root Safe
    /// @param oldLimit uint256 Old Limit of Tree
    /// @param newLimit uint256 New Limit of Tree
    event NewLimitLevel(
        bytes32 indexed org,
        uint256 indexed rootSafeId,
        address indexed updater,
        uint256 oldLimit,
        uint256 newLimit
    );

    /// @dev Event Fire when remove a Safe (Tier 0) from the organisation
    /// @param org Hash (On-chain Organisation)
    /// @param safeId ID of the safe Disconnect
    /// @param safe Address of Safe Address of the safe Disconnect
    /// @param disconnector Address of the disconnector
    event SafeDisconnected(
        bytes32 indexed org,
        uint256 indexed safeId,
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
