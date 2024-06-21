// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";

/// @title TestPalmeraSafe
/// @custom:security-contact general@palmeradao.xyz
contract TestPalmeraSafe is SigningUtils, DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    // ! ********************** authority Test **********************************

    // Checks if authority == palmeraRoles
    function testAuthorityAddress() public {
        assertEq(
            address(palmeraModule.authority()), address(palmeraRolesDeployed)
        );
    }

    // ! ********************** Allow/Deny list Test ********************

    // Revert AddresNotAllowed() execTransactionOnBehalf (safeA1 is not on AllowList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA1
    // Target Info: Type-> SAFE, Name -> safeSubSafeA1, Hierarchy related to caller -> NOT_ALLOW_LIST
    function testRevertSuperSafeExecOnBehalfIsNotAllowList() public {
        (uint256 rootId, uint256 safeA1Id, uint256 subSafeA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);

        // Send ETH to safe&subsafe
        vm.deal(safeA1Addr, 100 gwei);
        vm.deal(subSafeA1Addr, 100 gwei);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        palmeraModule.enableAllowlist();
        vm.stopPrank();

        // Set palmerahelper safe to safeA1
        palmeraHelper.setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeA1Addr);
        vm.expectRevert(Errors.AddresNotAllowed.selector);
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA1
    // Target Info: Type-> SAFE, Name -> safeSubSafeA1, Hierarchy related to caller -> DENY_LIST
    function testRevertSuperSafeExecOnBehalfIsDenyList() public {
        (uint256 rootId, uint256 safeA1Id, uint256 subSafeA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);

        // Send ETH to safe&subsafe
        vm.deal(safeA1Addr, 100 gwei);
        vm.deal(subSafeA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(rootAddr);
        palmeraModule.enableDenylist();
        palmeraModule.addToList(receiverList);
        vm.stopPrank();

        // Set palmerahelper safe to safeA1
        palmeraHelper.setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeA1Addr);
        vm.expectRevert(Errors.AddressDenied.selector);
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA1
    // Target Info: Type-> SAFE, Name -> safeSubSafeA1, Hierarchy related to caller -> DENY_LIST
    function testDisableDenyHelperList() public {
        (uint256 rootId, uint256 safeA1Id, uint256 subSafeA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);

        // Send ETH to safe&subsafe
        vm.deal(safeA1Addr, 100 gwei);
        vm.deal(subSafeA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        palmeraModule.enableDenylist();
        palmeraModule.addToList(receiverList);
        /// Disable allowlist
        palmeraModule.disableDenyHelper();
        vm.stopPrank();

        // Set palmerahelper safe to safeA1
        palmeraHelper.setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeA1Addr);
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            safeA1Addr,
            subSafeA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // ! ******************** registerOrg Test *************************************

    // Revert ("UNAUTHORIZED") registerOrg (address that has no roles)
    function testRevertAuthForRegisterOrgTx() public {
        address caller = address(0x1);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        palmeraRolesContract.setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD), caller, Constants.ADD_OWNER, true
        );
    }

    // ! ******************** removeSafe Test *************************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> safeA1, Hierarchy related to caller -> SAME_TREE
    function testCan_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree()
        public
    {
        (
            uint256 rootId,
            uint256 safeA1Id,
            uint256 subSafeA1Id,
            uint256 subSubsafeA1Id
        ) = palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(subSafeA1Id);
        assertEq(result, true);
        assertEq(palmeraModule.isSuperSafe(rootId, subSafeA1Id), false);

        // Check safeSubSafeA1 is now a child of org
        assertEq(palmeraModule.isTreeMember(rootId, subSubsafeA1Id), true);
        // Check org is parent of safeSubSafeA1
        assertEq(palmeraModule.isSuperSafe(safeA1Id, subSubsafeA1Id), true);

        // Check removed safe parent has subSafe A as child an not safeA1
        uint256[] memory child;
        (,,,, child,) = palmeraModule.getSafeInfo(safeA1Id);
        assertEq(child.length, 1);
        assertEq(child[0] == subSafeA1Id, false);
        assertEq(child[0] == subSubsafeA1Id, true);
        assertEq(palmeraModule.isTreeMember(rootId, subSafeA1Id), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> safeB, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannot_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentTree(
    ) public {
        (uint256 rootIdA, uint256 safeAId, uint256 rootIdB, uint256 safeBId) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeBId);
        vm.stopPrank();

        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeAId);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> ROOT_SAFE, Name -> rootB, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannot_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentOrg(
    ) public {
        (uint256 rootIdA, uint256 safeAId, uint256 rootIdB, uint256 safeBId,,) =
        palmeraSafeBuilder.setupTwoOrgWithOneRootOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeBId);
        vm.stopPrank();

        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> safeA
    // Target Info: Type-> SAFE, Name -> subSafeA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testCan_RemoveSafe_SUPER_SAFE_as_SAFE_is_SUPER_SAFE_SameTree()
        public
    {
        (uint256 rootId, uint256 safeA1Id, uint256 subSafeA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address safeAAddr = palmeraModule.getSafeAddress(safeA1Id);

        safeHelper.updateSafeInterface(safeAAddr);
        bool result = safeHelper.createRemoveSafeTx(subSafeA1Id);
        assertEq(result, true);
        assertEq(palmeraModule.isSuperSafe(safeA1Id, subSafeA1Id), false);
        assertEq(palmeraModule.isSuperSafe(rootId, subSafeA1Id), false);
        assertEq(palmeraModule.isTreeMember(rootId, subSafeA1Id), false);

        // Check supersafe has not any children
        (,,,, uint256[] memory child,) = palmeraModule.getSafeInfo(safeA1Id);
        assertEq(child.length, 0);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> safeA
    // Target Info: Type-> SAFE, Name -> safeB, Hierarchy related to caller -> DIFFERENT_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveSafe_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_DifferentTree(
    ) public {
        (, uint256 safeAId,, uint256 safeBId,,) = palmeraSafeBuilder
            .setupTwoOrgWithOneRootOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address safeAAddr = palmeraModule.getSafeAddress(safeAId);
        vm.startPrank(safeAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeBId);
        vm.stopPrank();

        address safeBAddr = palmeraModule.getSafeAddress(safeBId);
        vm.startPrank(safeBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(safeAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA
    // Target Info: Type-> SAFE, Name -> subsubSafeA, Hierarchy related to caller -> SAME_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveSafe_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_SameTree(
    ) public {
        (, uint256 safeAId,, uint256 subSubSafeA1) = palmeraSafeBuilder
            .setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address safeAAddr = palmeraModule.getSafeAddress(safeAId);
        vm.startPrank(safeAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        palmeraModule.removeSafe(subSubSafeA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> safeA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testRemoveSafeAndCheckDisables() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);

        (,,,,, uint256 superSafeId) = palmeraModule.getSafeInfo(safeA1Id);
        (,, address superSafeAddr,,) = palmeraModule.safes(orgHash, superSafeId);

        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(safeA1Id);
        assertEq(result, true);

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SUPER_SAFE, Name -> safeA, Hierarchy related to caller -> SAME_TREE
    function testCan_hasNotPermissionOverTarget_is_root_of_target() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeAddr = palmeraModule.getSafeAddress(safeA1Id);

        bool result = palmeraModule.hasNotPermissionOverTarget(
            rootAddr, orgHash, safeAddr
        );
        assertFalse(result);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Super, Name -> safeA
    // Target Info: Type-> ROOT_SAFE, Name -> rootA, Hierarchy related to caller -> SAME_TREE
    function testCan_hasNotPermissionOverTarget_is_not_root_of_target()
        public
    {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeAddr = palmeraModule.getSafeAddress(safeA1Id);

        bool result = palmeraModule.hasNotPermissionOverTarget(
            safeAddr, orgHash, rootAddr
        );
        assertTrue(result);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Super, Name -> safeA
    // Target Info: Type-> CHILD_SAFE, Name -> subSafeA, Hierarchy related to caller -> SAME_TREE
    function testCan_hasNotPermissionOverTarget_is_super_safe_of_target()
        public
    {
        (, uint256 safeA1Id, uint256 subSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeAddr = palmeraModule.getSafeAddress(safeA1Id);
        address subSafeAddr = palmeraModule.getSafeAddress(subSafeA1Id);

        bool result = palmeraModule.hasNotPermissionOverTarget(
            safeAddr, orgHash, subSafeAddr
        );
        assertFalse(result);
    }

    // Caller Info: Role-> CHILD_SAFE, Type -> SAFE, Hierarchy -> Child, Name -> subSafeA
    // Target Info: Type-> SUPER_SAFE, Name -> safeA, Hierarchy related to caller -> SAME_TREE
    function testCan_hasNotPermissionOverTarget_is_not_super_safe_of_target()
        public
    {
        (, uint256 safeA1Id, uint256 subSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeAddr = palmeraModule.getSafeAddress(safeA1Id);
        address subSafeAddr = palmeraModule.getSafeAddress(subSafeA1Id);

        bool result = palmeraModule.hasNotPermissionOverTarget(
            subSafeAddr, orgHash, safeAddr
        );
        assertTrue(result);
    }
}
