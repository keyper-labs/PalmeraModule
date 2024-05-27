// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

/// @title Hierarchies
/// @custom:security-contact general@palmeradao.xyz
contract Hierarchies is DeployHelper {
    /// Function called before each test is run
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    /// @notice Test Register Root Organisation
    function testRegisterRootOrg() public {
        bool result = safeHelper.registerOrgTx(orgName);
        assertEq(result, true);
        assertEq(orgHash, keccak256(abi.encodePacked(orgName)));
        uint256 rootId = palmeraModule.getSquadIdBySafe(
            orgHash, address(safeHelper.safeWallet())
        );
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSquadInfo(rootId);
        assertEq(uint8(tier), uint8(DataTypes.Tier.ROOT));
        assertEq(name, orgName);
        assertEq(lead, address(0));
        assertEq(safe, address(safeHelper.safeWallet()));
        assertEq(superSafe, 0);
        assertEq(child.length, 0);
        assertEq(palmeraModule.isOrgRegistered(orgHash), true);
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safe, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );
    }

    /// @notice Test Add Squad to Root Organisation
    function testAddSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        (
            DataTypes.Tier tier,
            string memory squadName,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSquadInfo(squadIdA1);

        assertEq(uint256(tier), uint256(DataTypes.Tier.SQUAD));
        assertEq(squadName, squadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, address(safeHelper.safeWallet()));
        assertEq(child.length, 0);
        assertEq(superSafe, rootId);

        address squadAddr = palmeraModule.getSquadSafeAddress(squadIdA1);
        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);

        assertEq(palmeraModule.isRootSafeOf(rootAddr, squadIdA1), true);
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                squadAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    /// @notice Test Expect Invalid Squad Id
    function testExpectInvalidSquadId() public {
        uint256 orgIdNotRegistered = 2;
        vm.expectRevert(Errors.InvalidSquadId.selector);
        palmeraModule.addSquad(orgIdNotRegistered, squadA1Name);
    }

    /// @notice Test Expect Squad Not Registered
    function testExpectSquadNotRegistered() public {
        uint256 orgIdNotRegistered = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SquadNotRegistered.selector, orgIdNotRegistered
            )
        );
        palmeraModule.addSquad(orgIdNotRegistered, squadA1Name);
    }

    /// @notice Test Add SubSquad to Squad
    function testAddSubSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address squadBaddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(squadBaddr);
        uint256 squadIdB = palmeraModule.addSquad(squadIdA1, squadBName);
        assertEq(palmeraModule.isTreeMember(rootId, squadIdA1), true);
        assertEq(palmeraModule.isSuperSafe(rootId, squadIdA1), true);
        assertEq(palmeraModule.isTreeMember(squadIdA1, squadIdB), true);
        assertEq(palmeraModule.isSuperSafe(squadIdA1, squadIdB), true);
    }

    /// @notice Test an Org with Tree Levels of Tree Member
    function testTreeOrgsTreeMember() public {
        (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );
        assertEq(palmeraModule.isTreeMember(rootId, squadIdA1), true);
        assertEq(palmeraModule.isTreeMember(squadIdA1, subSquadIdA1), true);
        (uint256 rootId2, uint256 squadIdB) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(root2Name, squadBName);
        assertEq(palmeraModule.isTreeMember(rootId2, squadIdB), true);
        assertEq(palmeraModule.isTreeMember(rootId2, rootId), false);
        assertEq(palmeraModule.isTreeMember(rootId2, squadIdA1), false);
        assertEq(palmeraModule.isTreeMember(rootId, squadIdB), false);
    }

    /// @notice Test if a Squad is Super Safe
    function testIsSuperSafe() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subsubSquadIdA1
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );
        assertEq(palmeraModule.isSuperSafe(rootId, squadIdA1), true);
        assertEq(palmeraModule.isSuperSafe(squadIdA1, subSquadIdA1), true);
        assertEq(palmeraModule.isSuperSafe(subSquadIdA1, subsubSquadIdA1), true);
        assertEq(
            palmeraModule.isSuperSafe(subsubSquadIdA1, subSquadIdA1), false
        );
        assertEq(palmeraModule.isSuperSafe(subsubSquadIdA1, squadIdA1), false);
        assertEq(palmeraModule.isSuperSafe(subsubSquadIdA1, rootId), false);
        assertEq(palmeraModule.isSuperSafe(subSquadIdA1, squadIdA1), false);
    }

    /// @notice Test Update Super Safe
    function testUpdateSuper() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 squadIdB,
            uint256 subSquadIdA1,
            uint256 subsubSquadIdA1
        ) = palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSubSquadA1Name
        );
        address rootSafe = palmeraModule.getSquadSafeAddress(rootId);
        address squadA1 = palmeraModule.getSquadSafeAddress(squadIdA1);
        address squadBB = palmeraModule.getSquadSafeAddress(squadIdB);
        address subSquadA1 = palmeraModule.getSquadSafeAddress(subSquadIdA1);

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                squadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                squadBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSquadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(palmeraModule.isTreeMember(rootId, subSquadIdA1), true);
        vm.startPrank(rootSafe);
        palmeraModule.updateSuper(subSquadIdA1, squadIdB);
        vm.stopPrank();
        assertEq(palmeraModule.isSuperSafe(squadIdB, subSquadIdA1), true);
        assertEq(palmeraModule.isSuperSafe(squadIdA1, subSquadIdA1), false);
        assertEq(palmeraModule.isSuperSafe(squadIdA1, subSquadIdA1), false);
        assertEq(palmeraModule.isSuperSafe(squadIdA1, subsubSquadIdA1), false);
        assertEq(palmeraModule.isTreeMember(squadIdA1, subsubSquadIdA1), false);
        assertEq(palmeraModule.isTreeMember(squadIdB, subsubSquadIdA1), true);
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                squadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                squadBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    /// @notice Test Revert Expected when Update Super Invalid Squad Id
    function testRevertUpdateSuperInvalidSquadId() public {
        (uint256 rootId, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        // Get root info
        address rootSafe = palmeraModule.getSquadSafeAddress(rootId);

        uint256 squadNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidSquadId.selector);
        vm.startPrank(rootSafe);
        palmeraModule.updateSuper(squadIdA1, squadNotRegisteredId);
    }

    /// @notice Test Revert Expected when Update Super if Caller is not Safe
    function testRevertUpdateSuperIfCallerIsNotSafe() public {
        (uint256 rootId, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        vm.startPrank(address(0xDDD));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, address(0xDDD))
        );
        palmeraModule.updateSuper(squadIdA1, rootId);
        vm.stopPrank();
    }

    /// @notice Test Revert Expected when Update Super if Caller is not Part of the Org
    function testRevertUpdateSuperIfCallerNotPartofTheOrg() public {
        (uint256 rootId, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        (uint256 rootId2,) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(root2Name, squadBName);
        // Get root2 info
        address rootSafe2 = palmeraModule.getSquadSafeAddress(rootId2);
        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSquad.selector);
        palmeraModule.updateSuper(squadIdA1, rootId);
        vm.stopPrank();
    }

    /// @notice Test Create Squad Three Tiers Tree
    function testCreateSquadThreeTiersTree() public {
        (uint256 orgRootId, uint256 safeSquadA1Id, uint256 safeSubSquadA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address safeSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSquadA1Id);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSquadInfo(safeSquadA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.SQUAD));
        assertEq(name, squadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSquadA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], safeSubSquadA1Id);
        assertEq(superSafe, orgRootId);

        /// Reuse the local-variable for avoid stack too deep error
        (tier, name, lead, safe, child, superSafe) =
            palmeraModule.getSquadInfo(safeSubSquadA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.SQUAD));
        assertEq(name, subSquadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSubSquadA1Addr);
        assertEq(child.length, 0);
        assertEq(superSafe, safeSquadA1Id);
    }

    /// @notice Test Create Squad Four Tiers Tree
    function testOrgFourTiersTreeSuperSafeRoles() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subSubSquadIdA1
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(squadIdA1);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(subSquadIdA1);
        address safeSubSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(subSubSquadIdA1);

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeSubSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeSubSubSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
    }

    /// @notice Test Revert Expected when Add Squad Already Registered
    function testRevertSafeAlreadyRegisteredAddSquad() public {
        (, uint256 squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address safeSubSquadA1 = safeHelper.newPalmeraSafe(2, 1);
        safeHelper.updateSafeInterface(safeSubSquadA1);

        bool result = safeHelper.createAddSquadTx(squadIdA1, subSquadA1Name);
        assertEq(result, true);

        vm.startPrank(safeSubSquadA1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeAlreadyRegistered.selector, safeSubSquadA1
            )
        );
        palmeraModule.addSquad(squadIdA1, subSquadA1Name);

        vm.deal(safeSubSquadA1, 1 ether);
        safeHelper.updateSafeInterface(safeSubSquadA1);

        vm.expectRevert();
        result = safeHelper.createAddSquadTx(squadIdA1, subSquadA1Name);
    }

    // ! **************** List of Test for Depth Tree Limits *******************************
    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit with Invalid Value
    function testRevertIfTryInvalidLimit() public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidLimit.selector);
        palmeraModule.updateDepthTreeLimit(0);
        vm.expectRevert(Errors.InvalidLimit.selector);
        palmeraModule.updateDepthTreeLimit(7);
        vm.expectRevert(Errors.InvalidLimit.selector);
        palmeraModule.updateDepthTreeLimit(51); // 50 is the max limit
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit from Non Root Safe
    function testRevertIfTryNotRootSafe() public {
        (, uint256 squadA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address squadA = palmeraModule.getSquadSafeAddress(squadA1Id);
        vm.startPrank(squadA);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.updateDepthTreeLimit(10);
        vm.stopPrank();

        (,,, uint256 lastSubSquad) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        address LastSubSquad = palmeraModule.getSquadSafeAddress(lastSubSquad);
        vm.startPrank(LastSubSquad);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidRootSafe.selector, LastSubSquad
            )
        );
        palmeraModule.updateDepthTreeLimit(10);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit with a Value to Exceed the Max Limit
    function testRevertifExceedMaxDepthTreeLimit() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](9);
        uint256[] memory subSquadAid = new uint256[](9);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = palmeraModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[i]);
            // Add the new Safe as a subSquad
            if (i != 8) {
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit and Exceed the Max Limit
    function testRevertifUpdateLimitAndExceedMaxDepthTreeLimit() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](16);
        uint256[] memory subSquadAid = new uint256[](16);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = palmeraModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        // depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[i]);
            // Add the new Safe as a subSquad
            if (i != 8) {
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
        vm.startPrank(subSquadAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[j]);
            // Add the new Safe as a subSquad
            if (j != 15) {
                subSquadAid[j] =
                    palmeraModule.addSquad(subSquadAid[j - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                palmeraModule.addSquad(subSquadAid[j - 1], squadBName);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit and Update Super
    function testRevertifExceedMaxDepthTreeLimitAndUpdateSuper() public {
        (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            ,
            uint256 subSquadA,
            uint256 subSquadB
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            org2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](9);
        uint256[] memory subSquadAid = new uint256[](9);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootIdA);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootIdA;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;

        // Address of Root B
        address rootAddrB = palmeraModule.getSquadSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        console.log("depthTreeLimit: ", depthTreeLimit);

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.updateSuper(subSquadB, subSquadAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit and Exceed the Max Limit and Update Super
    function testRevertifUpdateLimitAndExceedMaxDepthTreeLimitAndUpdateSuper()
        public
    {
        (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            ,
            uint256 subSquadA,
            uint256 subSquadB
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            org2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](16);
        uint256[] memory subSquadAid = new uint256[](16);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootIdA);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootIdA;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;

        // Address of Root B
        address rootAddrB = palmeraModule.getSquadSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.updateSuper(subSquadB, subSquadAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
        vm.startPrank(subSquadAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSquadAaddr[j]);
                subSquadAid[j] =
                    palmeraModule.addSquad(subSquadAid[j - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                palmeraModule.updateSuper(subSquadB, subSquadAid[j - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit and Update Super to Another Org
    function testRevertifUpdateSuperToAnotherOrg() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );

        (uint256 rootId2, uint256 squadB) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadBName);
        address rootId2Addr = palmeraModule.getSquadSafeAddress(rootId2);
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](9);
        uint256[] memory subSquadAid = new uint256[](9);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = palmeraModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                palmeraModule.updateSuper(squadB, subSquadAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit and Exceed the Max Limit and Update Super to Another Org
    function testRevertifUpdateDepthTreeLimitAndUpdateSuperToAnotherOrg()
        public
    {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );

        (uint256 rootId2, uint256 squadB) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadBName);
        address rootId2Addr = palmeraModule.getSquadSafeAddress(rootId2);
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](16);
        uint256[] memory subSquadAid = new uint256[](16);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = palmeraModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = palmeraModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = palmeraModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = palmeraModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    palmeraModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                palmeraModule.updateSuper(squadB, subSquadAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }

        vm.startPrank(subSquadAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSquad
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSquadAaddr[j]);
                subSquadAid[j] =
                    palmeraModule.addSquad(subSquadAid[j - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                palmeraModule.updateSuper(squadB, subSquadAid[j - 1]);
                assertEq(palmeraModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }
}
