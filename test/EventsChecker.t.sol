// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

contract EventsChekers is DeployHelper {
    address[] public owners = new address[](5);
    /// @dev Event Fire when create a new Organization

    event OrganizationCreated(
        address indexed creator, bytes32 indexed org, string name
    );
    /// @dev Event Fire when create a New Squad (Tier 0) into the organization
    event SquadCreated(
        bytes32 indexed org,
        uint256 indexed squadCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );
    /// @dev Event Fire when remove a Squad (Tier 0) from the organization
    event SquadRemoved(
        bytes32 indexed org,
        uint256 indexed squadRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Squad (Tier 0) from the organization
    event SquadSuperUpdated(
        bytes32 indexed org,
        uint256 indexed squadUpdated,
        address lead,
        address indexed updater,
        uint256 oldSuperSafe,
        uint256 newSuperSafe
    );

    /// @dev Event Fire when Keyper Module execute a transaction on behalf of a Safe
    event TxOnBehalfExecuted(
        bytes32 indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    /// @dev Event Fire when any Root Safe create a new Root Safe
    event RootSafeSquadCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeSquad,
        address indexed creator,
        address newRootSafeSquad,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Squad To Root Safe
    event RootSafePromoted(
        bytes32 indexed org,
        uint256 indexed newIdRootSafeSquad,
        address indexed updater,
        address newRootSafeSquad,
        string name
    );

    /// @dev Event Fire when an Root Safe Remove Whole of Tree
    event WholeTreeRemoved(
        bytes32 indexed org,
        uint256 indexed rootSafeSquadId,
        address indexed remover,
        string name
    );

    /// @dev Event Fire when any Root Safe change Depth Tree Limit
    event NewLimitLevel(
        bytes32 indexed org,
        uint256 indexed rootSafeSquadId,
        address indexed updater,
        uint256 oldLimit,
        uint256 newLimit
    );

    /// @dev Event Fire when remove a Squad (Tier 0) from the organization
    event SafeDisconnected(
        bytes32 indexed org,
        uint256 indexed squad,
        address indexed safe,
        address disconnector
    );

    /// @notice Events Deny Helpers

    /// @dev Event Fire when add several wallet into the deny/allow list
    event AddedToList(address[] users);

    /// @dev Event Fire when drop a wallet into the deny/allow list
    event DroppedFromList(address indexed user);

    // Function called before each test is run
    function setUp() public {
        DeployHelper.deployAllContracts(90);
        /// Owners
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0xDDD);
        owners[4] = address(0xEEE);
    }

    function testEventWhenRegisterRootOrg() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();
    }

    function testEventWhenAddSquad() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
    }

    function testEventWhenRemoveSquad() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
        vm.stopPrank();

        // Remove Squad through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadRemoved(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            rootAddr,
            rootId,
            squadA1Name
            );
        keyperModule.removeSquad(squadId);
    }

    function testEventWhenRegisterRootSafe() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Register Root Safe through safe tx
        address rootSafeAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafeSquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            rootAddr,
            rootSafeAddr,
            org2Name
            );
        keyperModule.createRootSafeSquad(rootSafeAddr, org2Name);
    }

    function testEventWhenUpdateSuper() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Register Root Safe through safe tx
        address rootSafeAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 rootsafeId = 2;
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafeSquadCreated(
            keccak256(abi.encodePacked(orgName)),
            rootsafeId,
            rootAddr,
            rootSafeAddr,
            org2Name
            );
        keyperModule.createRootSafeSquad(rootSafeAddr, org2Name);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 3;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
        vm.stopPrank();

        // Update Super through safe tx
        address newRootSafeAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadSuperUpdated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            rootAddr,
            rootId,
            rootsafeId
            );
        keyperModule.updateSuper(squadId, rootsafeId);
    }

    function testEventWhenPromoteRootSafe() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
        vm.stopPrank();

        // Add Squad through safe tx
        address childSquadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 childSquadId = 3;
        vm.startPrank(childSquadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            childSquadId,
            address(0),
            childSquadAddr,
            squadId,
            subSquadA1Name
            );
        keyperModule.addSquad(squadId, subSquadA1Name);
        vm.stopPrank();

        // Promote Squad to Root Safe through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafePromoted(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            rootAddr,
            squadAddr,
            squadA1Name
            );
        keyperModule.promoteRoot(squadId);
    }

    function testEventWhenDisconnectSafe() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
        vm.stopPrank();

        // Remove Squad through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadRemoved(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            rootAddr,
            rootId,
            squadA1Name
            );
        keyperModule.removeSquad(squadId);

        // Disconnect Squad through safe tx
        vm.expectEmit(true, true, true, true);
        emit SafeDisconnected(
            keccak256(abi.encodePacked(orgName)), squadId, squadAddr, rootAddr
            );
        keyperModule.disconnectSafe(squadId);
    }

    function testEventWhenExecutionOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit TxOnBehalfExecuted(
            keccak256(abi.encodePacked(orgName)),
            rootAddr,
            safeSquadA1Addr,
            true
            );
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    function testEventWhenRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subSubSquadIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit WholeTreeRemoved(
            keccak256(abi.encodePacked(orgName)), rootId, rootAddr, orgName
            );
        keyperModule.removeWholeTree();
    }

    function testEventWhenUpdateNewLimit() public {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganizationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
            );
        uint256 rootId = keyperModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Squad through safe tx
        address squadAddr = gnosisHelper.newKeyperSafe(4, 2);
        uint256 squadId = 2;
        vm.startPrank(squadAddr);
        vm.expectEmit(true, true, true, true);
        emit SquadCreated(
            keccak256(abi.encodePacked(orgName)),
            squadId,
            address(0),
            squadAddr,
            rootId,
            squadA1Name
            );
        keyperModule.addSquad(rootId, squadA1Name);
        vm.stopPrank();

        // Update new limit through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit NewLimitLevel(
            keccak256(abi.encodePacked(orgName)), rootId, rootAddr, 8, 49
            );
        keyperModule.updateDepthTreeLimit(49);
    }

    function testEventWhenAddToList() public {
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        uint256 rootId = keyperModule.registerOrg(orgName);
        keyperModule.enableAllowlist();
        vm.expectEmit(true, false, false, true);
        emit AddedToList(owners);
        keyperModule.addToList(owners);
    }

    function testEventWhenDropFromList() public {
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(rootAddr);
        uint256 rootId = keyperModule.registerOrg(orgName);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        vm.expectEmit(true, false, false, true);
        emit DroppedFromList(owners[0]);
        keyperModule.dropFromList(owners[0]);
    }
}
