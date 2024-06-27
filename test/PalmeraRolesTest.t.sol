// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "./helpers/DeployHelper.t.sol";

/// @title PalmeraRolesTest
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraRolesTest is DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    /// @notice Auxiliary function to deploy PalmeraRoles contract
    function testCan_PalmeraModule_Setup_RoleContract() public {
        // Check PalmeraModule has role capabilites
        assertEq(
            palmeraRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                palmeraModuleAddr,
                Constants.ADD_OWNER
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                palmeraModuleAddr,
                Constants.REMOVE_OWNER
            ),
            true
        );
        // Check roleAuthority owner is set to palmera module
        assertEq(palmeraRolesContract.owner(), palmeraModuleAddr);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    function testCan_ROOT_SAFE_SetRole_ROOT_SAFE_When_RegisterOrg() public {
        address org1 = safeAddr;
        vm.startPrank(org1);

        palmeraModule.registerOrg(orgName);
        // Check Role
        assertEq(
            palmeraRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.ROOT_SAFE),
                address(palmeraModule),
                Constants.ROLE_ASSIGMENT
            ),
            true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> EAO, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address userEOALead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, userEOALead, safeA1Id, true
        );

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                userEOALead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(palmeraModule.isSafeLead(safeA1Id, userEOALead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> SafeA, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_SAFE() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address safeLead = safeHelper.newPalmeraSafe(4, 2);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        vm.startPrank(rootAddr);

        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeLead, safeA1Id, true
        );

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(palmeraModule.isSafeLead(safeA1Id, safeLead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SafeA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        palmeraModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeA1Id, true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA
    // Target Info: Type-> EOA, Name -> user, Hierarchy related to caller -> N/A
    function testCannot_SUPER_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);

        address user = address(0xABCDE);

        vm.startPrank(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, safeA1Addr)
        );
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, user, safeA1Id, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> root
    // Target Info: Type-> SAFE, Name -> safeA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_SAFE() public {
        (uint256 rootId, uint256 safeA1Id, uint256 subSafeAId,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeAddr = palmeraModule.getSafeAddress(safeA1Id);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        palmeraModule.setRole(
            DataTypes.Role.SUPER_SAFE, safeAddr, subSafeAId, true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SafeA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        palmeraModule.setRole(DataTypes.Role.SUPER_SAFE, user, safeA1Id, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SafeA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EOA_DifferentTree_Safe()
        public
    {
        (uint256 rootIdA,,, uint256 safeBId) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address user = address(0xABCDE);
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorizedSetRoleAnotherTree.selector
            )
        );
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, user, safeBId, true);
    }

    /// ************** Additional Test for SetRoles  / disableSafeLeadRoles ************** ///

    /// @notice Vefigy setting multiples Lead roles, in any case when the safe is disconnect not preserve any Safe Lead Role
    function testNotPreserveAnyRoleAfterDisconnectSafe() public {
        (uint256 rootIdA, uint256 safeAId, uint256 rootIdB, uint256 safeBId) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );
        // get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);
        address safeAIdAddr = palmeraModule.getSafeAddress(safeAId);
        address safeBIdAddr = palmeraModule.getSafeAddress(safeBId);

        // Set at least Two Safe Lead Role to safeBIdAddr over rootIdA
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeBIdAddr, rootIdA, true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            safeBIdAddr,
            rootIdA,
            true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            safeBIdAddr,
            rootIdA,
            true
        );
        vm.stopPrank();
        // Verify the Roles Setting for safeBIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdA, safeBIdAddr));
        // Set at least Two Safe Lead Role to safeAIdAddr over rootIdB
        vm.startPrank(rootBAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeAIdAddr, rootIdB, true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            safeAIdAddr,
            rootIdB,
            true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            safeAIdAddr,
            rootIdB,
            true
        );
        vm.stopPrank();
        // Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdB, safeAIdAddr));

        // Disconnect SafeAIdAddr from RootIdA
        vm.startPrank(rootAddr);
        palmeraModule.disconnectSafe(safeAId);
        vm.stopPrank();
        // Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        // Disconnect SafeBIdAddr from RootIdB
        vm.startPrank(rootBAddr);
        palmeraModule.disconnectSafe(safeBId);
        vm.stopPrank();
        // Verify the Roles Setting for safeBIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeBIdAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );

        // disconnect RootA
        vm.startPrank(rootAddr);
        palmeraModule.disconnectSafe(rootIdA);
        vm.stopPrank();

        // verify the roles setting for rootA
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            false
        );
    }
}
