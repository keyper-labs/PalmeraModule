// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";

contract TestKeyperSafe is SigningUtils, DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    // ! ********************** authority Test **********************************

    // Checks if authority == keyperRoles
    function testAuthorityAddress() public {
        assertEq(
            address(keyperModule.authority()), address(keyperRolesDeployed)
        );
    }

    // ! ********************** createSafeFactory Test **************************

    // Checks if a safe is created successfully from Module
    // function testCreateSafeFromModule() public {
    //     address newSafe = keyperHelper.createSafeProxy(4, 2);
    //     assertFalse(newSafe == address(0));
    //     // Verify newSafe has keyper modulle enabled
    //     GnosisSafe safe = GnosisSafe(payable(newSafe));
    //     bool isKeyperModuleEnabled =
    //         safe.isModuleEnabled(address(keyperHelper.keyper()));
    //     assertEq(isKeyperModuleEnabled, true);
    // }

    // ! ********************** Allow/Deny list Test ********************

    // Revert AddresNotAllowed() execTransactionOnBehalf (safeSquadA1 is not on AllowList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> safeSquadA1
    // Target Info: Type-> SAFE, Name -> safeSubSquadA1, Hierarchy related to caller -> NOT_ALLOW_LIST
    function testRevertSuperSafeExecOnBehalfIsNotAllowList() public {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Send ETH to squad&subsquad
        vm.deal(squadA1Addr, 100 gwei);
        vm.deal(subSquadA1Addr, 100 gwei);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableAllowlist();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeSquadA1
        keyperHelper.setGnosisSafe(squadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(squadA1Addr);
        vm.expectRevert(Errors.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeSquadA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> safeSquadA1
    // Target Info: Type-> SAFE, Name -> safeSubSquadA1, Hierarchy related to caller -> DENY_LIST
    function testRevertSuperSafeExecOnBehalfIsDenyList() public {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Send ETH to squad&subsquad
        vm.deal(squadA1Addr, 100 gwei);
        vm.deal(subSquadA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeSquadA1
        keyperHelper.setGnosisSafe(squadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(squadA1Addr);
        vm.expectRevert(Errors.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeSquadA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> safeSquadA1
    // Target Info: Type-> SAFE, Name -> safeSubSquadA1, Hierarchy related to caller -> DENY_LIST
    function testDisableDenyHelperList() public {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Send ETH to squad&subsquad
        vm.deal(squadA1Addr, 100 gwei);
        vm.deal(subSquadA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        /// Disable allowlist
        keyperModule.disableDenyHelper();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeSquadA1
        keyperHelper.setGnosisSafe(squadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(squadA1Addr);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            squadA1Addr,
            subSquadA1Addr,
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
        keyperRolesContract.setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD), caller, Constants.ADD_OWNER, true
        );
    }

    // ! ******************** removeSquad Test *************************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> safeSquadA1, Hierarchy related to caller -> SAME_TREE
    function testCan_RemoveSquad_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree()
        public
    {
        (
            uint256 rootId,
            uint256 squadA1Id,
            uint256 subSquadA1Id,
            uint256 subSubsquadA1Id
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(rootId, subSquadA1Id), false);

        // Check safeSubSquadA1 is now a child of org
        assertEq(keyperModule.isTreeMember(rootId, subSubsquadA1Id), true);
        // Check org is parent of safeSubSquadA1
        assertEq(keyperModule.isSuperSafe(squadA1Id, subSubsquadA1Id), true);

        // Check removed squad parent has subSafeSquad A as child an not safeSquadA1
        uint256[] memory child;
        (,,,, child,) = keyperModule.getSquadInfo(squadA1Id);
        assertEq(child.length, 1);
        assertEq(child[0] == subSquadA1Id, false);
        assertEq(child[0] == subSubsquadA1Id, true);
        assertEq(keyperModule.isTreeMember(rootId, subSquadA1Id), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> squadB, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannot_RemoveSquad_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentTree(
    ) public {
        (uint256 rootIdA, uint256 squadAId, uint256 rootIdB, uint256 squadBId) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadBId);
        vm.stopPrank();

        address rootBAddr = keyperModule.getSquadSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadAId);
    }

    function testCannot_RemoveSquad_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentOrg(
    ) public {
        (uint256 rootIdA, uint256 squadAId, uint256 rootIdB, uint256 squadBId,,)
        = keyperSafeBuilder.setupTwoOrgWithOneRootOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadBId);
        vm.stopPrank();

        address rootBAddr = keyperModule.getSquadSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> squadA
    // Target Info: Type-> SAFE, Name -> subSquadA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testCan_RemoveSquad_SUPER_SAFE_as_SAFE_is_SUPER_SAFE_SameTree()
        public
    {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address squadAAddr = keyperModule.getSquadSafeAddress(squadA1Id);

        gnosisHelper.updateSafeInterface(squadAAddr);
        bool result = gnosisHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(squadA1Id, subSquadA1Id), false);
        assertEq(keyperModule.isSuperSafe(rootId, subSquadA1Id), false);
        assertEq(keyperModule.isTreeMember(rootId, subSquadA1Id), false);

        // Check supersafe has not any children
        (,,,, uint256[] memory child,) = keyperModule.getSquadInfo(squadA1Id);
        assertEq(child.length, 0);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> squadA
    // Target Info: Type-> SAFE, Name -> squadB, Hierarchy related to caller -> DIFFERENT_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveSquad_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_DifferentTree(
    ) public {
        (, uint256 squadAId,, uint256 squadBId,,) = keyperSafeBuilder
            .setupTwoOrgWithOneRootOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address squadAAddr = keyperModule.getSquadSafeAddress(squadAId);
        vm.startPrank(squadAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadBId);
        vm.stopPrank();

        address squadBAddr = keyperModule.getSquadSafeAddress(squadBId);
        vm.startPrank(squadBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(squadAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> squadA
    // Target Info: Type-> SAFE, Name -> subsubSquadA, Hierarchy related to caller -> SAME_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveSquad_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_SameTree(
    ) public {
        (, uint256 squadAId,, uint256 subSubSquadA1) = keyperSafeBuilder
            .setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address squadAAddr = keyperModule.getSquadSafeAddress(squadAId);
        vm.startPrank(squadAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotRootOrSuperSafe.selector);
        keyperModule.removeSquad(subSubSquadA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> squadA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testRemoveSquadAndCheckDisables() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        (,,,,, uint256 superSafe) = keyperModule.getSquadInfo(squadA1Id);
        (,, address superSafeAddr,,) = keyperModule.squads(orgHash, superSafe);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(squadA1Id);
        assertEq(result, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                squadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
    }

    function testCan_hasNotPermissionOverTarget_is_root_of_target() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadAddr = keyperModule.getSquadSafeAddress(squadA1Id);

        bool result = keyperModule.hasNotPermissionOverTarget(
            rootAddr, orgHash, squadAddr
        );
        assertFalse(result);
    }

    function testCan_hasNotPermissionOverTarget_is_not_root_of_target()
        public
    {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadAddr = keyperModule.getSquadSafeAddress(squadA1Id);

        bool result = keyperModule.hasNotPermissionOverTarget(
            squadAddr, orgHash, rootAddr
        );
        assertTrue(result);
    }

    function testCan_hasNotPermissionOverTarget_is_super_safe_of_target()
        public
    {
        (, uint256 squadA1Id, uint256 subSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadAddr = keyperModule.getSquadSafeAddress(squadA1Id);
        address subSquadAddr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        bool result = keyperModule.hasNotPermissionOverTarget(
            squadAddr, orgHash, subSquadAddr
        );
        assertFalse(result);
    }

    function testCan_hasNotPermissionOverTarget_is_not_super_safe_of_target()
        public
    {
        (, uint256 squadA1Id, uint256 subSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadAddr = keyperModule.getSquadSafeAddress(squadA1Id);
        address subSquadAddr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        bool result = keyperModule.hasNotPermissionOverTarget(
            subSquadAddr, orgHash, squadAddr
        );
        assertTrue(result);
    }
}
