// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

contract Hierarchies is DeployHelper {
    // Function called before each test is run
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    function testRegisterRootOrg() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        assertEq(result, true);
        assertEq(orgHash, keccak256(abi.encodePacked(orgName)));
        uint256 rootId = keyperModule.getSquadIdBySafe(
            orgHash, address(gnosisHelper.gnosisSafe())
        );
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getSquadInfo(rootId);
        assertEq(uint8(tier), uint8(DataTypes.Tier.ROOT));
        assertEq(name, orgName);
        assertEq(lead, address(0));
        assertEq(safe, address(gnosisHelper.gnosisSafe()));
        assertEq(superSafe, 0);
        assertEq(child.length, 0);
        assertEq(keyperModule.isOrgRegistered(orgHash), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safe, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );
    }

    function testAddSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        (
            DataTypes.Tier tier,
            string memory squadName,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getSquadInfo(squadIdA1);

        assertEq(uint256(tier), uint256(DataTypes.Tier.SQUAD));
        assertEq(squadName, squadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, address(gnosisHelper.gnosisSafe()));
        assertEq(child.length, 0);
        assertEq(superSafe, rootId);

        address squadAddr = keyperModule.getSquadSafeAddress(squadIdA1);
        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        assertEq(keyperModule.isRootSafeOf(rootAddr, squadIdA1), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    function testExpectInvalidSquadId() public {
        uint256 orgIdNotRegistered = 2;
        vm.expectRevert(Errors.InvalidSquadId.selector);
        keyperModule.addSquad(orgIdNotRegistered, squadA1Name);
    }

    function testExpectSquadNotRegistered() public {
        uint256 orgIdNotRegistered = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SquadNotRegistered.selector, orgIdNotRegistered
            )
        );
        keyperModule.addSquad(orgIdNotRegistered, squadA1Name);
    }

    function testAddSubSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address squadBaddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(squadBaddr);
        uint256 squadIdB = keyperModule.addSquad(squadIdA1, squadBName);
        assertEq(keyperModule.isTreeMember(rootId, squadIdA1), true);
        assertEq(keyperModule.isSuperSafe(rootId, squadIdA1), true);
        assertEq(keyperModule.isTreeMember(squadIdA1, squadIdB), true);
        assertEq(keyperModule.isSuperSafe(squadIdA1, squadIdB), true);
    }

    function testTreeOrgsTreeMember() public {
        (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );
        assertEq(keyperModule.isTreeMember(rootId, squadIdA1), true);
        assertEq(keyperModule.isTreeMember(squadIdA1, subSquadIdA1), true);
        (uint256 rootId2, uint256 squadIdB) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(root2Name, squadBName);
        assertEq(keyperModule.isTreeMember(rootId2, squadIdB), true);
        assertEq(keyperModule.isTreeMember(rootId2, rootId), false);
        assertEq(keyperModule.isTreeMember(rootId2, squadIdA1), false);
        assertEq(keyperModule.isTreeMember(rootId, squadIdB), false);
    }

    function testIsSuperSafe() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subsubSquadIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );
        assertEq(keyperModule.isSuperSafe(rootId, squadIdA1), true);
        assertEq(keyperModule.isSuperSafe(squadIdA1, subSquadIdA1), true);
        assertEq(keyperModule.isSuperSafe(subSquadIdA1, subsubSquadIdA1), true);
        assertEq(keyperModule.isSuperSafe(subsubSquadIdA1, subSquadIdA1), false);
        assertEq(keyperModule.isSuperSafe(subsubSquadIdA1, squadIdA1), false);
        assertEq(keyperModule.isSuperSafe(subsubSquadIdA1, rootId), false);
        assertEq(keyperModule.isSuperSafe(subSquadIdA1, squadIdA1), false);
    }

    function testUpdateSuper() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 squadIdB,
            uint256 subSquadIdA1,
            uint256 subsubSquadIdA1
        ) = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSubSquadA1Name
        );
        address rootSafe = keyperModule.getSquadSafeAddress(rootId);
        address squadA1 = keyperModule.getSquadSafeAddress(squadIdA1);
        address squadBB = keyperModule.getSquadSafeAddress(squadIdB);
        address subSquadA1 = keyperModule.getSquadSafeAddress(subSquadIdA1);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                subSquadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(keyperModule.isTreeMember(rootId, subSquadIdA1), true);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(subSquadIdA1, squadIdB);
        vm.stopPrank();
        assertEq(keyperModule.isSuperSafe(squadIdB, subSquadIdA1), true);
        assertEq(keyperModule.isSuperSafe(squadIdA1, subSquadIdA1), false);
        assertEq(keyperModule.isSuperSafe(squadIdA1, subSquadIdA1), false);
        assertEq(keyperModule.isSuperSafe(squadIdA1, subsubSquadIdA1), false);
        assertEq(keyperModule.isTreeMember(squadIdA1, subsubSquadIdA1), false);
        assertEq(keyperModule.isTreeMember(squadIdB, subsubSquadIdA1), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    function testRevertUpdateSuperInvalidSquadId() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        // Get root info
        address rootSafe = keyperModule.getSquadSafeAddress(rootId);

        uint256 squadNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidSquadId.selector);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(squadIdA1, squadNotRegisteredId);
    }

    function testRevertUpdateSuperIfCallerIsNotSafe() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        vm.startPrank(address(0xDDD));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, address(0xDDD))
        );
        keyperModule.updateSuper(squadIdA1, rootId);
        vm.stopPrank();
    }

    function testRevertUpdateSuperIfCallerNotPartofTheOrg() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        (uint256 rootId2,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(root2Name, squadBName);
        // Get root2 info
        address rootSafe2 = keyperModule.getSquadSafeAddress(rootId2);
        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSquad.selector);
        keyperModule.updateSuper(squadIdA1, rootId);
        vm.stopPrank();
    }

    function testCreateSquadThreeTiersTree() public {
        (uint256 orgRootId, uint256 safeSquadA1Id, uint256 safeSubSquadA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address safeSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSquadA1Id);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getSquadInfo(safeSquadA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.SQUAD));
        assertEq(name, squadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSquadA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], safeSubSquadA1Id);
        assertEq(superSafe, orgRootId);

        /// Reuse the local-variable for avoid stack too deep error
        (tier, name, lead, safe, child, superSafe) =
            keyperModule.getSquadInfo(safeSubSquadA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.SQUAD));
        assertEq(name, subSquadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSubSquadA1Addr);
        assertEq(child.length, 0);
        assertEq(superSafe, safeSquadA1Id);
    }

    function testOrgFourTiersTreeSuperSafeRoles() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subSubSquadIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(subSquadIdA1);
        address safeSubSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(subSubSquadIdA1);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubSubSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
    }

    function testRevertSafeAlreadyRegisteredAddSquad() public {
        (, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address safeSubSquadA1 = gnosisHelper.newKeyperSafe(2, 1);
        gnosisHelper.updateSafeInterface(safeSubSquadA1);

        bool result = gnosisHelper.createAddSquadTx(squadIdA1, subSquadA1Name);
        assertEq(result, true);

        vm.startPrank(safeSubSquadA1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeAlreadyRegistered.selector, safeSubSquadA1
            )
        );
        keyperModule.addSquad(squadIdA1, subSquadA1Name);

        vm.deal(safeSubSquadA1, 1 ether);
        gnosisHelper.updateSafeInterface(safeSubSquadA1);

        vm.expectRevert();
        result = gnosisHelper.createAddSquadTx(squadIdA1, subSquadA1Name);
    }

    // ! **************** List of Test for Depth Tree Limits *******************************
    function testRevertIfTryInvalidLimit() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidLimit.selector);
        keyperModule.updateDepthTreeLimit(0);
        vm.expectRevert(Errors.InvalidLimit.selector);
        keyperModule.updateDepthTreeLimit(7);
        vm.expectRevert(Errors.InvalidLimit.selector);
        keyperModule.updateDepthTreeLimit(51); // 50 is the max limit
        vm.stopPrank();
    }

    function testRevertIfTryNotRootSafe() public {
        (, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address squadA = keyperModule.getSquadSafeAddress(squadA1Id);
        vm.startPrank(squadA);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        keyperModule.updateDepthTreeLimit(10);
        vm.stopPrank();

        (,,, uint256 lastSubSquad) = keyperSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        address LastSubSquad = keyperModule.getSquadSafeAddress(lastSubSquad);
        vm.startPrank(LastSubSquad);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidRootSafe.selector, LastSubSquad
            )
        );
        keyperModule.updateDepthTreeLimit(10);
        vm.stopPrank();
    }

    function testRevertifExceedMaxDepthTreeLimit() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](9);
        uint256[] memory subSquadAid = new uint256[](9);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = keyperModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[i]);
            // Add the new Safe as a subSquad
            if (i != 8) {
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
    }

    function testRevertifUpdateLimitAndExceedMaxDepthTreeLimit() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](16);
        uint256[] memory subSquadAid = new uint256[](16);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = keyperModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        // depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[i]);
            // Add the new Safe as a subSquad
            if (i != 8) {
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
        vm.startPrank(subSquadAaddr[0]);
        keyperModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = gnosisHelper.newKeyperSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[j]);
            // Add the new Safe as a subSquad
            if (j != 15) {
                subSquadAid[j] =
                    keyperModule.addSquad(subSquadAid[j - 1], squadBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                keyperModule.addSquad(subSquadAid[j - 1], squadBName);
                assertEq(keyperModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
    }

    function testRevertifExceedMaxDepthTreeLimitAndUpdateSuper() public {
        (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            ,
            uint256 subSquadA,
            uint256 subSquadB
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
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
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootIdA);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootIdA;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;

        // Address of Root B
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;
        console.log("depthTreeLimit: ", depthTreeLimit);

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                keyperModule.updateSuper(subSquadB, subSquadAid[i - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

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
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
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
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootIdA);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootIdA;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;

        // Address of Root B
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                keyperModule.updateSuper(subSquadB, subSquadAid[i - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
        vm.startPrank(subSquadAaddr[0]);
        keyperModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSquadAaddr[j]);
                subSquadAid[j] =
                    keyperModule.addSquad(subSquadAid[j - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                keyperModule.updateSuper(subSquadB, subSquadAid[j - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

    function testRevertifUpdateSuperToAnotherOrg() public {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );

        (uint256 rootId2, uint256 squadB) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadBName);
        address rootId2Addr = keyperModule.getSquadSafeAddress(rootId2);
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](9);
        uint256[] memory subSquadAid = new uint256[](9);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = keyperModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                keyperModule.updateSuper(squadB, subSquadAid[i - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }

    function testRevertifUpdateDepthTreeLimitAndUpdateSuperToAnotherOrg()
        public
    {
        (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadA,
            uint256 subSubSquadA
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            org2Name, squadA2Name, subSquadA1Name, subSubSquadA1Name
        );

        (uint256 rootId2, uint256 squadB) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadBName);
        address rootId2Addr = keyperModule.getSquadSafeAddress(rootId2);
        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](16);
        uint256[] memory subSquadAid = new uint256[](16);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);
        subSquadAaddr[2] = keyperModule.getSquadSafeAddress(subSquadA);
        subSquadAaddr[3] = keyperModule.getSquadSafeAddress(subSubSquadA);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;
        subSquadAid[2] = subSquadA;
        subSquadAid[3] = subSubSquadA;

        /// depth Tree Lmit by org
        bytes32 org = keyperModule.getOrgHashBySafe(subSquadAaddr[0]);
        uint256 depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSquadAaddr[i]);
                subSquadAid[i] =
                    keyperModule.addSquad(subSquadAid[i - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                keyperModule.updateSuper(squadB, subSquadAid[i - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }

        vm.startPrank(subSquadAaddr[0]);
        keyperModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = keyperModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSquadAaddr[j] = gnosisHelper.newKeyperSafe(3, 1);
            // Add the new Safe as a subSquad
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSquadAaddr[j]);
                subSquadAid[j] =
                    keyperModule.addSquad(subSquadAid[j - 1], squadBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSquadToOtherOrg.selector
                );
                keyperModule.updateSuper(squadB, subSquadAid[j - 1]);
                assertEq(keyperModule.isLimitLevel(subSquadAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }
}
