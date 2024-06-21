// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "./helpers/DeployHelper.t.sol";

/// @title EventsChecker
/// @custom:security-contact general@palmeradao.xyz
contract EventsChekers is DeployHelper {
    address[] public owners = new address[](5);
    /// @dev Event Fire when create a new Organisation

    event OrganisationCreated(
        address indexed creator, bytes32 indexed org, string name
    );
    /// @dev Event Fire when create a New Safe (Tier 0) into the organisation
    event SafeCreated(
        bytes32 indexed org,
        uint256 indexed safeCreated,
        address lead,
        address indexed creator,
        uint256 superSafe,
        string name
    );
    /// @dev Event Fire when remove a Safe (Tier 0) from the organisation
    event SafeRemoved(
        bytes32 indexed org,
        uint256 indexed safeRemoved,
        address lead,
        address indexed remover,
        uint256 superSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Safe (Tier 0) from the organisation
    event SafeSuperUpdated(
        bytes32 indexed org,
        uint256 indexed safeUpdated,
        address lead,
        address indexed updater,
        uint256 oldSuperSafe,
        uint256 newSuperSafe
    );

    /// @dev Event Fire when Palmera Module execute a transaction on behalf of a Safe
    event TxOnBehalfExecuted(
        bytes32 indexed org,
        address indexed executor,
        address superSafe,
        address indexed targetSafe,
        bool result
    );

    /// @dev Event Fire when any Root Safe create a new Root Safe
    event RootSafeCreated(
        bytes32 indexed org,
        uint256 indexed newIdRootSafe,
        address indexed creator,
        address newRootSafe,
        string name
    );

    /// @dev Event Fire when update SuperSafe of a Safe To Root Safe
    event RootSafePromoted(
        bytes32 indexed org,
        uint256 indexed newIdRootSafe,
        address indexed updater,
        address newRootSafe,
        string name
    );

    /// @dev Event Fire when an Root Safe Remove Whole of Tree
    event WholeTreeRemoved(
        bytes32 indexed org,
        uint256 indexed rootSafeId,
        address indexed remover,
        string name
    );

    /// @dev Event Fire when any Root Safe change Depth Tree Limit
    event NewLimitLevel(
        bytes32 indexed org,
        uint256 indexed rootSafeId,
        address indexed updater,
        uint256 oldLimit,
        uint256 newLimit
    );

    /// @dev Event Fire when remove a Safe (Tier 0) from the organisation
    event SafeDisconnected(
        bytes32 indexed org,
        uint256 indexed safeId,
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

    /// @notice Test Events when Register Root Organisation
    function testEventWhenRegisterRootOrg() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();
    }

    /// @notice Test Events when Add Safe
    function testEventWhenAddSafe() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
    }

    /// @notice Test Events when Remove Safe
    function testEventWhenRemoveSafe() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
        vm.stopPrank();

        // Remove Safe through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeRemoved(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            rootAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.removeSafe(safeId);
    }

    /// @notice Test Events when Register Root Safe
    function testEventWhenRegisterRootSafe() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Register Root Safe through safe tx
        address rootSafeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            rootAddr,
            rootSafeAddr,
            org2Name
        );
        palmeraModule.createRootSafe(rootSafeAddr, org2Name);
    }

    /// @notice Test Events when Update Super Safe
    function testEventWhenUpdateSuper() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Register Root Safe through safe tx
        address rootSafeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 rootsafeId = 2;
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafeCreated(
            keccak256(abi.encodePacked(orgName)),
            rootsafeId,
            rootAddr,
            rootSafeAddr,
            org2Name
        );
        palmeraModule.createRootSafe(rootSafeAddr, org2Name);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 3;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
        vm.stopPrank();

        // Update Super through safe tx
        address newRootSafeAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeSuperUpdated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            rootAddr,
            rootId,
            rootsafeId
        );
        palmeraModule.updateSuper(safeId, rootsafeId);
    }

    /// @notice Test Events when Promote Safe to Root Safe
    function testEventWhenPromoteRootSafe() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
        vm.stopPrank();

        // Add Safe through safe tx
        address childSafeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 childSafeId = 3;
        vm.startPrank(childSafeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            childSafeId,
            address(0),
            childSafeAddr,
            safeId,
            subSafeA1Name
        );
        palmeraModule.addSafe(safeId, subSafeA1Name);
        vm.stopPrank();

        // Promote Safe to Root Safe through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit RootSafePromoted(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            rootAddr,
            safeAddr,
            safeA1Name
        );
        palmeraModule.promoteRoot(safeId);
    }

    /// @notice Test Events when Disconnect Safe
    function testEventWhenDisconnectSafe() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
        vm.stopPrank();

        // Remove Safe through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeRemoved(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            rootAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.removeSafe(safeId);

        // Disconnect Safe through safe tx
        vm.expectEmit(true, true, true, true);
        emit SafeDisconnected(
            keccak256(abi.encodePacked(orgName)), safeId, safeAddr, rootAddr
        );
        palmeraModule.disconnectSafe(safeId);
    }

    /// @notice Test Events when Call Execution on Behalf
    function testEventWhenExecutionOnBehalf() public {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
            rootAddr,
            safeA1Addr,
            true
        );
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    /// @notice Test Events when Remove Whole Tree
    function testEventWhenRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeIdA1,
            uint256 subSubSafeIdA1
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit WholeTreeRemoved(
            keccak256(abi.encodePacked(orgName)), rootId, rootAddr, orgName
        );
        palmeraModule.removeWholeTree();
    }

    /// @notice Test Events when Update New Limit
    function testEventWhenUpdateNewLimit() public {
        // Register Org through safe tx
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, false, true);
        emit OrganisationCreated(
            rootAddr, keccak256(abi.encodePacked(orgName)), orgName
        );
        uint256 rootId = palmeraModule.registerOrg(orgName);
        vm.stopPrank();

        // Add Safe through safe tx
        address safeAddr = safeHelper.newPalmeraSafe(4, 2);
        uint256 safeId = 2;
        vm.startPrank(safeAddr);
        vm.expectEmit(true, true, true, true);
        emit SafeCreated(
            keccak256(abi.encodePacked(orgName)),
            safeId,
            address(0),
            safeAddr,
            rootId,
            safeA1Name
        );
        palmeraModule.addSafe(rootId, safeA1Name);
        vm.stopPrank();

        // Update new limit through safe tx
        vm.startPrank(rootAddr);
        vm.expectEmit(true, true, true, true);
        emit NewLimitLevel(
            keccak256(abi.encodePacked(orgName)), rootId, rootAddr, 8, 49
        );
        palmeraModule.updateDepthTreeLimit(49);
    }

    /// @notice Test Events when Add Address to Enable/Denied Allow List
    function testEventWhenAddToList() public {
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        uint256 rootId = palmeraModule.registerOrg(orgName);
        palmeraModule.enableAllowlist();
        vm.expectEmit(true, false, false, true);
        emit AddedToList(owners);
        palmeraModule.addToList(owners);
    }

    /// @notice Test Events when Drop Address to Enable/Denied Allow List
    function testEventWhenDropFromList() public {
        address rootAddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(rootAddr);
        uint256 rootId = palmeraModule.registerOrg(orgName);
        palmeraModule.enableAllowlist();
        palmeraModule.addToList(owners);
        vm.expectEmit(true, false, false, true);
        emit DroppedFromList(owners[0]);
        palmeraModule.dropFromList(owners[0]);
    }
}
