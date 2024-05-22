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
        uint256 rootId = palmeraModule.getSafeIdBySafe(
            orgHash, address(safeHelper.safeWallet())
        );
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSafeInfo(rootId);
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

    /// @notice Test Add Safe to Root Organisation
    function testAddSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        (
            DataTypes.Tier tier,
            string memory safeName,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSafeInfo(safeIdA1);

        assertEq(uint256(tier), uint256(DataTypes.Tier.safe));
        assertEq(safeName, safeA1Name);
        assertEq(lead, address(0));
        assertEq(safe, address(safeHelper.safeWallet()));
        assertEq(child.length, 0);
        assertEq(superSafe, rootId);

        address safeAddr = palmeraModule.getSafeAddress(safeIdA1);
        address rootAddr = palmeraModule.getSafeAddress(rootId);

        assertEq(palmeraModule.isRootSafeOf(rootAddr, safeIdA1), true);
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAddr, uint8(DataTypes.Role.SUPER_SAFE)
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

    /// @notice Test Expect Invalid Safe Id
    function testExpectInvalidSafeId() public {
        uint256 orgIdNotRegistered = 2;
        vm.expectRevert(Errors.InvalidSafeId.selector);
        palmeraModule.addSafe(orgIdNotRegistered, safeA1Name);
    }

    /// @notice Test Expect Safe Not Registered
    function testExpectSafeNotRegistered() public {
        uint256 orgIdNotRegistered = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeIdNotRegistered.selector, orgIdNotRegistered
            )
        );
        palmeraModule.addSafe(orgIdNotRegistered, safeA1Name);
    }

    /// @notice Test Add SubSafe to Safe
    function testAddSubSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        address safeBaddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(safeBaddr);
        uint256 safeIdB = palmeraModule.addSafe(safeIdA1, safeBName);
        assertEq(palmeraModule.isTreeMember(rootId, safeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(rootId, safeIdA1), true);
        assertEq(palmeraModule.isTreeMember(safeIdA1, safeIdB), true);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, safeIdB), true);
    }

    /// @notice Test an Org with Tree Levels of Tree Member
    function testTreeOrgsTreeMember() public {
        (uint256 rootId, uint256 safeIdA1, uint256 subSafeIdA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );
        assertEq(palmeraModule.isTreeMember(rootId, safeIdA1), true);
        assertEq(palmeraModule.isTreeMember(safeIdA1, subSafeIdA1), true);
        (uint256 rootId2, uint256 safeIdB) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(root2Name, safeBName);
        assertEq(palmeraModule.isTreeMember(rootId2, safeIdB), true);
        assertEq(palmeraModule.isTreeMember(rootId2, rootId), false);
        assertEq(palmeraModule.isTreeMember(rootId2, safeIdA1), false);
        assertEq(palmeraModule.isTreeMember(rootId, safeIdB), false);
    }

    /// @notice Test if a Safe is Super Safe
    function testIsSuperSafe() public {
        (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeIdA1,
            uint256 subsubSafeIdA1
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );
        assertEq(palmeraModule.isSuperSafe(rootId, safeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, subSafeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(subSafeIdA1, subsubSafeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(subsubSafeIdA1, subSafeIdA1), false);
        assertEq(palmeraModule.isSuperSafe(subsubSafeIdA1, safeIdA1), false);
        assertEq(palmeraModule.isSuperSafe(subsubSafeIdA1, rootId), false);
        assertEq(palmeraModule.isSuperSafe(subSafeIdA1, safeIdA1), false);
    }

    /// @notice Test Update Super Safe
    function testUpdateSuper() public {
        (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 safeIdB,
            uint256 subSafeIdA1,
            uint256 subsubSafeIdA1
        ) = palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, safeA1Name, safeBName, subSafeA1Name, subSubSafeA1Name
        );
        address rootSafe = palmeraModule.getSafeAddress(rootId);
        address safeA1 = palmeraModule.getSafeAddress(safeIdA1);
        address safeBB = palmeraModule.getSafeAddress(safeIdB);
        address subSafeA1 = palmeraModule.getSafeAddress(subSafeIdA1);

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(palmeraModule.isTreeMember(rootId, subSafeIdA1), true);
        vm.startPrank(rootSafe);
        palmeraModule.updateSuper(subSafeIdA1, safeIdB);
        vm.stopPrank();
        assertEq(palmeraModule.isSuperSafe(safeIdB, subSafeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, subSafeIdA1), false);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, subSafeIdA1), false);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, subsubSafeIdA1), false);
        assertEq(palmeraModule.isTreeMember(safeIdA1, subsubSafeIdA1), false);
        assertEq(palmeraModule.isTreeMember(safeIdB, subsubSafeIdA1), true);
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    /// @notice Test Revert Expected when Update Super Invalid Safe Id
    function testRevertUpdateSuperInvalidSafeId() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        // Get root info
        address rootSafe = palmeraModule.getSafeAddress(rootId);

        uint256 safeNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidSafeId.selector);
        vm.startPrank(rootSafe);
        palmeraModule.updateSuper(safeIdA1, safeNotRegisteredId);
    }

    /// @notice Test Revert Expected when Update Super if Caller is not Safe
    function testRevertUpdateSuperIfCallerIsNotSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        vm.startPrank(address(0xDDD));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, address(0xDDD))
        );
        palmeraModule.updateSuper(safeIdA1, rootId);
        vm.stopPrank();
    }

    /// @notice Test Revert Expected when Update Super if Caller is not Part of the Org
    function testRevertUpdateSuperIfCallerNotPartofTheOrg() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        (uint256 rootId2,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(root2Name, safeBName);
        // Get root2 info
        address rootSafe2 = palmeraModule.getSafeAddress(rootId2);
        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSafe.selector);
        palmeraModule.updateSuper(safeIdA1, rootId);
        vm.stopPrank();
    }

    /// @notice Test Create Safe Three Tiers Tree
    function testCreateSafeThreeTiersTree() public {
        (uint256 orgRootId, uint256 safeA1Id, uint256 safeSubSafeA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = palmeraModule.getSafeInfo(safeA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.safe));
        assertEq(name, safeA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], safeSubSafeA1Id);
        assertEq(superSafe, orgRootId);

        /// Reuse the local-variable for avoid stack too deep error
        (tier, name, lead, safe, child, superSafe) =
            palmeraModule.getSafeInfo(safeSubSafeA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.safe));
        assertEq(name, subSafeA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSubSafeA1Addr);
        assertEq(child.length, 0);
        assertEq(superSafe, safeA1Id);
    }

    /// @notice Test Create Safe Four Tiers Tree
    function testOrgFourTiersTreeSuperSafeRoles() public {
        (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeIdA1,
            uint256 subSubSafeIdA1
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address safeSubSafeA1Addr = palmeraModule.getSafeAddress(subSafeIdA1);
        address safeSubSubSafeA1Addr =
            palmeraModule.getSafeAddress(subSubSafeIdA1);

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeSubSafeA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeSubSubSafeA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
    }

    /// @notice Test Revert Expected when Add Safe Already Registered
    function testRevertSafeAlreadyRegisteredAddSafe() public {
        (, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address safeSubSafeA1 = safeHelper.newPalmeraSafe(2, 1);
        safeHelper.updateSafeInterface(safeSubSafeA1);

        bool result = safeHelper.createAddSafeTx(safeIdA1, subSafeA1Name);
        assertEq(result, true);

        vm.startPrank(safeSubSafeA1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeAlreadyRegistered.selector, safeSubSafeA1
            )
        );
        palmeraModule.addSafe(safeIdA1, subSafeA1Name);

        vm.deal(safeSubSafeA1, 1 ether);
        safeHelper.updateSafeInterface(safeSubSafeA1);

        vm.expectRevert();
        result = safeHelper.createAddSafeTx(safeIdA1, subSafeA1Name);
    }

    // ! **************** List of Test for Depth Tree Limits *******************************
    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit with Invalid Value
    function testRevertIfTryInvalidLimit() public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        address rootAddr = palmeraModule.getSafeAddress(rootId);
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
        (, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        address safeA = palmeraModule.getSafeAddress(safeA1Id);
        vm.startPrank(safeA);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, safeA)
        );
        palmeraModule.updateDepthTreeLimit(10);
        vm.stopPrank();

        (,,, uint256 lastSubSafe) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, safeA2Name, subSafeA1Name, subSubSafeA1Name
        );
        address LastSubSafe = palmeraModule.getSafeAddress(lastSubSafe);
        vm.startPrank(LastSubSafe);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, LastSubSafe)
        );
        palmeraModule.updateDepthTreeLimit(10);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if Try to Update Depth Tree Limit with a Value to Exceed the Max Limit
    function testRevertifExceedMaxDepthTreeLimit() public {
        (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeA,
            uint256 subSubSafeA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, safeA2Name, subSafeA1Name, subSubSafeA1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](9);
        uint256[] memory subSafeAid = new uint256[](9);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootId);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(subSubSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;
        subSafeAid[3] = subSubSafeA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSafeAaddr[i]);
            // Add the new Safe as a subSafe
            if (i != 8) {
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
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
            uint256 safeIdA1,
            uint256 subSafeA,
            uint256 subSubSafeA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, safeA2Name, subSafeA1Name, subSubSafeA1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](16);
        uint256[] memory subSafeAid = new uint256[](16);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootId);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(subSubSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;
        subSafeAid[3] = subSubSafeA;

        // depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSafeAaddr[i]);
            // Add the new Safe as a subSafe
            if (i != 8) {
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
            }
            vm.stopPrank();
        }
        vm.startPrank(subSafeAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSafeAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSafeAaddr[j]);
            // Add the new Safe as a subSafe
            if (j != 15) {
                subSafeAid[j] =
                    palmeraModule.addSafe(subSafeAid[j - 1], safeBName);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                palmeraModule.addSafe(subSafeAid[j - 1], safeBName);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[j - 1]), true);
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
            uint256 safeIdA1,
            uint256 rootIdB,
            ,
            uint256 subSafeA,
            uint256 subSafeB
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](9);
        uint256[] memory subSafeAid = new uint256[](9);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootIdA);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootIdA;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;

        // Address of Root B
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        console.log("depthTreeLimit: ", depthTreeLimit);

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSafeAaddr[i]);
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.updateSuper(subSafeB, subSafeAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
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
            uint256 safeIdA1,
            uint256 rootIdB,
            ,
            uint256 subSafeA,
            uint256 subSafeB
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](16);
        uint256[] memory subSafeAid = new uint256[](16);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootIdA);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootIdA;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;

        // Address of Root B
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 3; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSafeAaddr[i]);
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, i
                    )
                );
                palmeraModule.updateSuper(subSafeB, subSafeAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
        vm.startPrank(subSafeAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSafeAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSafeAaddr[j]);
                subSafeAid[j] =
                    palmeraModule.addSafe(subSafeAid[j - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootAddrB);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Errors.TreeDepthLimitReached.selector, j
                    )
                );
                palmeraModule.updateSuper(subSafeB, subSafeAid[j - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[j - 1]), true);
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
            uint256 safeIdA1,
            uint256 subSafeA,
            uint256 subSubSafeA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, safeA2Name, subSafeA1Name, subSubSafeA1Name
        );

        (uint256 rootId2, uint256 safeB) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeBName);
        address rootId2Addr = palmeraModule.getSafeAddress(rootId2);
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](9);
        uint256[] memory subSafeAid = new uint256[](9);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootId);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(subSubSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;
        subSafeAid[3] = subSubSafeA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSafeAaddr[i]);
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSafeToOtherOrg.selector
                );
                palmeraModule.updateSuper(safeB, subSafeAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
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
            uint256 safeIdA1,
            uint256 subSafeA,
            uint256 subSubSafeA
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            org2Name, safeA2Name, subSafeA1Name, subSubSafeA1Name
        );

        (uint256 rootId2, uint256 safeB) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeBName);
        address rootId2Addr = palmeraModule.getSafeAddress(rootId2);
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](16);
        uint256[] memory subSafeAid = new uint256[](16);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootId);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(subSubSafeA);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA;
        subSafeAid[3] = subSubSafeA;

        /// depth Tree Lmit by org
        bytes32 org = palmeraModule.getOrgHashBySafe(subSafeAaddr[0]);
        uint256 depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;

        for (uint256 i = 4; i < depthTreeLimit; i++) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (i != 8) {
                // Start Prank
                vm.startPrank(subSafeAaddr[i]);
                subSafeAid[i] =
                    palmeraModule.addSafe(subSafeAid[i - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSafeToOtherOrg.selector
                );
                palmeraModule.updateSuper(safeB, subSafeAid[i - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[i - 1]), true);
                console.log("i: ", i);
                console.log("Max Depth Limit Reached");
                vm.stopPrank();
            }
        }

        vm.startPrank(subSafeAaddr[0]);
        palmeraModule.updateDepthTreeLimit(15);
        vm.stopPrank();

        // Update depth Tree Lmit by org
        depthTreeLimit = palmeraModule.depthTreeLimit(org) + 1;
        for (uint256 j = 8; j < depthTreeLimit; j++) {
            // Create a new Safe
            subSafeAaddr[j] = safeHelper.newPalmeraSafe(3, 1);
            // Add the new Safe as a subSafe
            if (j != 15) {
                // Start Prank
                vm.startPrank(subSafeAaddr[j]);
                subSafeAid[j] =
                    palmeraModule.addSafe(subSafeAid[j - 1], safeBName);
                vm.stopPrank();
            } else {
                vm.startPrank(rootId2Addr);
                vm.expectRevert(
                    Errors.NotAuthorizedUpdateSafeToOtherOrg.selector
                );
                palmeraModule.updateSuper(safeB, subSafeAid[j - 1]);
                assertEq(palmeraModule.isLimitLevel(subSafeAid[j - 1]), true);
                console.log("j: ", j);
                console.log("New Max Depth Limit Reached");
                vm.stopPrank();
            }
        }
    }
}
