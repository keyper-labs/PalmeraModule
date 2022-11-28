// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

library Events {

    /// @dev Events
    event OrganizationCreated(
        address indexed creator, bytes32 indexed org, string name
    );

    event GroupCreated(
        bytes32 indexed org,
        uint256 indexed groupCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );

    event GroupRemoved(
        bytes32 indexed org,
        uint256 indexed groupRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

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

    /// @dev Events
    event AddedToList(address[] users);
    event DroppedFromList(address indexed user);
}
