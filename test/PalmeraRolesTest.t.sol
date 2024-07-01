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

    /// @notice Verify setting multiples Lead roles, in any case when the safe is disconnect not preserve any Safe Lead Role in Org Differents
    function testNotPreserveAnySafeLeadRoleAfterDisconnectSafeDifferentOrg()
        public
    {
        (uint256 rootIdA, uint256 safeAId) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        (uint256 rootIdB, uint256 safeBId) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(org2Name, safeBName);
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
        // Must be false because the safe is disconnected, and all safe lead roles are removed
        assertFalse(palmeraModule.isSafeLead(rootIdB, safeAIdAddr));
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
        // Must be false because the safe is disconnected, and all safe lead roles are removed
        assertFalse(palmeraModule.isSafeLead(rootIdA, safeBIdAddr));

        // Set at least Two Safe Lead Role to rootAddr over rootIdB
        vm.startPrank(rootBAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, rootAddr, rootIdB, true);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY, rootAddr, rootIdB, true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rootAddr,
            rootIdB,
            true
        );
        vm.stopPrank();
        // Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdB, rootAddr));

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

    /// @notice Verify setting multiples Lead roles, in any case when the safe is disconnect not preserve any Safe Lead Role in Org Differents
    function testNotPreserveAnySafeLeadRoleAfterDisconnectSafeSameOrg()
        public
    {
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
        // Must be false because the safe is disconnected, and all safe lead roles are removed
        assertFalse(palmeraModule.isSafeLead(rootIdB, safeAIdAddr));
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
        // Must be false because the safe is disconnected, and all safe lead roles are removed
        assertFalse(palmeraModule.isSafeLead(rootIdA, safeBIdAddr));

        // Set at least Two Safe Lead Role to rootAddr over rootIdB
        vm.startPrank(rootBAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, rootAddr, rootIdB, true);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY, rootAddr, rootIdB, true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rootAddr,
            rootIdB,
            true
        );
        vm.stopPrank();
        // Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdB, rootAddr));

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

    /// @notice Verify any Safe config like Safe Lead Roles Modify Owners Only can execute any action like Safe Lead Role Exec on Behalf
    function test_SafeLeadExecuteTxOnBehalf_CanExecuteTransactionOnBehalf()
        public
    {
        (uint256 rootIdA,,,, uint256 subSafeIdA1,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            "subSafeB1"
        );

        ///get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address subSafeAIdAddr = palmeraModule.getSafeAddress(subSafeIdA1);

        ///Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            subSafeAIdAddr,
            rootIdA,
            true
        );
        vm.stopPrank();
        ///Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdA, subSafeAIdAddr));

        /// try to thief the Native Token of the Root Safe after disconnect the Safe
        bytes memory data;
        bytes memory signature; // empty signature because is not necessary for Safe Lead Role
        uint256 balanceRecipient = subSafeAIdAddr.balance;
        vm.startPrank(subSafeAIdAddr);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            rootAddr,
            subSafeAIdAddr,
            50 gwei,
            /// try to thief the Native Token of the Root Safe
            data,
            Enum.Operation.Call,
            signature
        );
        vm.stopPrank();
        assertEq(subSafeAIdAddr.balance, balanceRecipient + 50 gwei);
        assertTrue(result);
    }

    /// @notice Verify any Safe config like Safe Lead Role can't execute any action like Safe Lead Role on Execute on Behalf after disconnect Safe
    function testCannotSafeLeadRoleExecuteTxOnBehalfAfterDisconnectSafe()
        public
    {
        (uint256 rootIdA,,,, uint256 subSafeIdA1,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            "subSafeB1"
        );

        ///get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address subSafeAIdAddr = palmeraModule.getSafeAddress(subSafeIdA1);

        ///Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, subSafeAIdAddr, rootIdA, true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            subSafeAIdAddr,
            rootIdA,
            true
        );
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            subSafeAIdAddr,
            rootIdA,
            true
        );
        vm.stopPrank();
        ///Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdA, subSafeAIdAddr));

        /// confirm can execute on behalf after assign role
        uint256 balanceRecipient = subSafeAIdAddr.balance;
        bytes memory data;
        vm.startPrank(subSafeAIdAddr);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            rootAddr,
            subSafeAIdAddr,
            50 gwei,
            data,
            Enum.Operation.Call,
            "0x"
        );
        vm.stopPrank();
        assertEq(subSafeAIdAddr.balance, balanceRecipient + 50 gwei);
        assertTrue(result);

        ///Disconnect subSafeIdA1 from RootIdA
        vm.startPrank(rootAddr);
        palmeraModule.disconnectSafe(subSafeIdA1);
        vm.stopPrank();
        ///Verify the Roles Setting for subSafeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertFalse(palmeraModule.isSafeLead(rootIdA, subSafeAIdAddr));

        /// try to thief the Native Token of the Root Safe after disconnect the Safe
        vm.startPrank(subSafeAIdAddr);
        vm.expectRevert("GS020");
        result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            rootAddr,
            subSafeAIdAddr,
            50 gwei,
            /// try to thief the Native Token of the Root Safe
            data,
            Enum.Operation.Call,
            "0x"
        );
        vm.stopPrank();
        assertFalse(result);
    }

    /// @notice Verify any Safe config like Safe Lead Roles Modify Owners Only can't execute any action like Safe Lead Role Exec on Behalf
    function test_SafeLeadModifyOwnersOnly_CannotCanExecuteTransactionOnBehalf()
        public
    {
        (uint256 rootIdA,,,, uint256 subSafeIdA1,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            "subSafeB1"
        );

        ///get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address subSafeAIdAddr = palmeraModule.getSafeAddress(subSafeIdA1);

        ///Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            subSafeAIdAddr,
            rootIdA,
            true
        );
        vm.stopPrank();
        ///Verify the Roles Setting for safeAIdAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAIdAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            true
        );
        assertTrue(palmeraModule.isSafeLead(rootIdA, subSafeAIdAddr));

        /// try to thief the Native Token of the Root Safe after disconnect the Safe
        uint256 balanceRecipient = subSafeAIdAddr.balance;
        bytes memory data;
        bytes memory signature; // empty signature because is not necessary for Safe Lead Role
        vm.startPrank(subSafeAIdAddr);
        vm.expectRevert("GS020");
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            rootAddr,
            subSafeAIdAddr,
            50 gwei,
            /// try to thief the Native Token of the Root Safe
            data,
            Enum.Operation.Call,
            signature
        );
        vm.stopPrank();
        assertEq(subSafeAIdAddr.balance, balanceRecipient);
    }

    /// @notice Test to create a root Safe in one onchain org, remove Whole Tree it and after to add another or and verify not preserve any role
    function test_AnyRootSafeNotPreserveRootSafeRoleAfterRemoveWholeTree()
        public
    {
        (uint256 rootIdA,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        (, uint256 safeBId) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(org2Name, safeBName);
        // get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);

        // Verify Role of Root Safe
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );

        // Disconnect Root Safe from Org
        vm.startPrank(rootAddr);
        palmeraModule.removeWholeTree();
        vm.stopPrank();

        // Verify the Roles Setting for rootAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            false
        );

        // add old Root A Safe to Org 2 like subSafeA1
        vm.startPrank(rootAddr);
        uint256 subSafeB1Id = palmeraModule.addSafe(safeBId, "oldRootSafe");
        vm.stopPrank();

        address subSafeB1Addr = palmeraModule.getSafeAddress(subSafeB1Id);
        // Verify is the Same Address
        assertEq(rootAddr, subSafeB1Addr);

        // Verify the Roles Setting for rootAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeB1Addr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            false
        );
    }

    /// @notice Test to create a root Safe in one onchain org, disconnect it and after to add another or and verify not preserve any role
    function test_AnyRootSafeNotPreserveRootSafeRoleAfterDisconnect() public {
        (uint256 rootIdA, uint256 safeAId) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        (, uint256 safeBId) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(org2Name, safeBName);
        // get Address of the safes of both Orgs
        address rootAddr = palmeraModule.getSafeAddress(rootIdA);

        // Verify Role of Root Safe
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );

        // Disconnect Root Safe from Org
        vm.startPrank(rootAddr);
        palmeraModule.disconnectSafe(safeAId);
        palmeraModule.disconnectSafe(rootIdA);
        vm.stopPrank();

        // Verify the Roles Setting for rootAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            false
        );

        // add old Root A Safe to Org 2 like subSafeA1
        vm.startPrank(rootAddr);
        uint256 subSafeB1Id = palmeraModule.addSafe(safeBId, "oldRootSafe");
        vm.stopPrank();

        address subSafeB1Addr = palmeraModule.getSafeAddress(subSafeB1Id);
        // Verify is the Same Address
        assertEq(rootAddr, subSafeB1Addr);

        // Verify the Roles Setting for rootAddr
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeB1Addr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            false
        );
    }

    /// @notice Test to create a complex multi Root Org, assign one child Safe like a Safe Lead Role in multiples Safe of OnChain Org and Validate all al removed after disconnect
    function test_AnySafeNotPreserveSafeLeadRolesAfterDisconnectinTheSameOrg()
        public
    {
        (
            uint256 rootIdA,
            uint256 safeIdA1,
            uint256 rootIdB,
            uint256 safeIdB1,
            uint256 subSafeA1,
            uint256 subSafeB1
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](6);
        uint256[] memory subSafeAid = new uint256[](6);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootIdA);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA1);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(rootIdB);
        subSafeAaddr[4] = palmeraModule.getSafeAddress(safeIdB1);
        subSafeAaddr[5] = palmeraModule.getSafeAddress(subSafeB1);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootIdA;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA1;
        subSafeAid[3] = rootIdB;
        subSafeAid[4] = safeIdB1;
        subSafeAid[5] = subSafeB1;

        // Address of Root B
        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);

        // Assign subSafeB1 as Safe Lead Role in multiples Safe of OnChain Org
        for (uint256 i = 0; i < subSafeAaddr.length - 1; i++) {
            // Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
            vm.startPrank(subSafeAaddr[i <= 2 ? 0 : 3]);
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD, subSafeAaddr[5], subSafeAid[i], true
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                true
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                true
            );
            vm.stopPrank();
            // Verify the Roles Setting for subSafeB1
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5], uint8(DataTypes.Role.SAFE_LEAD)
                ),
                true
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
                ),
                true
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
                ),
                true
            );
            assertTrue(palmeraModule.isSafeLead(subSafeAid[i], subSafeAaddr[5]));
        }

        // disconnect subSafeB1 from RootIdB
        vm.startPrank(rootBAddr);
        palmeraModule.disconnectSafe(subSafeB1);
        vm.stopPrank();

        // Verify the Roles Setting for subSafeB1
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5], uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5],
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5],
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        for (uint256 i = 0; i < subSafeAaddr.length - 1; i++) {
            (,, address safeLead,,,) = palmeraModule.getSafeInfo(subSafeAid[i]);
            assertEq(safeLead, address(0));
            assertFalse(
                palmeraModule.isSafeLead(subSafeAid[i], subSafeAaddr[5])
            );
        }
    }

    /// @notice Test to create a complex multi Root Org, assign one child Safe like a Safe Lead Role in multiples Safe of OnChain Org and Validate all al removed after disconnect
    function test_AnySafeNotPreserveSafeLeadRolesAfterUnSetRole() public {
        (
            uint256 rootIdA,
            uint256 safeIdA1,
            uint256 rootIdB,
            uint256 safeIdB1,
            uint256 subSafeA1,
            uint256 subSafeB1
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );
        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](6);
        uint256[] memory subSafeAid = new uint256[](6);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootIdA);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);
        subSafeAaddr[2] = palmeraModule.getSafeAddress(subSafeA1);
        subSafeAaddr[3] = palmeraModule.getSafeAddress(rootIdB);
        subSafeAaddr[4] = palmeraModule.getSafeAddress(safeIdB1);
        subSafeAaddr[5] = palmeraModule.getSafeAddress(subSafeB1);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootIdA;
        subSafeAid[1] = safeIdA1;
        subSafeAid[2] = subSafeA1;
        subSafeAid[3] = rootIdB;
        subSafeAid[4] = safeIdB1;
        subSafeAid[5] = subSafeB1;

        // Address of Root B
        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);

        // Assign subSafeB1 as Safe Lead Role in multiples Safe of OnChain Org
        for (uint256 i = 0; i < subSafeAaddr.length - 1; i++) {
            // Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
            vm.startPrank(subSafeAaddr[i <= 2 ? 0 : 3]);
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD, subSafeAaddr[5], subSafeAid[i], true
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                true
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                true
            );
            vm.stopPrank();
            // Verify the Roles Setting for subSafeB1
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5], uint8(DataTypes.Role.SAFE_LEAD)
                ),
                true
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
                ),
                true
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
                ),
                true
            );
            assertTrue(palmeraModule.isSafeLead(subSafeAid[i], subSafeAaddr[5]));
        }

        // UnAssign subSafeB1 as Safe Lead Role in multiples Safe of OnChain Org
        for (uint256 i = 0; i < subSafeAaddr.length - 1; i++) {
            // Set at least Two Safe Lead Role to safeAIdAddr over rootIdA
            vm.startPrank(subSafeAaddr[i <= 2 ? 0 : 3]);
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD, subSafeAaddr[5], subSafeAid[i], false
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                false
            );
            palmeraModule.setRole(
                DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
                subSafeAaddr[5],
                subSafeAid[i],
                false
            );
            vm.stopPrank();
            // Verify the Roles Setting for subSafeB1
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5], uint8(DataTypes.Role.SAFE_LEAD)
                ),
                false
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
                ),
                false
            );
            assertEq(
                palmeraRolesContract.doesUserHaveRole(
                    subSafeAaddr[5],
                    uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
                ),
                false
            );
            assertFalse(
                palmeraModule.isSafeLead(subSafeAid[i], subSafeAaddr[5])
            );
        }

        // Verify the Roles Setting for subSafeB1
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5], uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5],
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                subSafeAaddr[5],
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        for (uint256 i = 0; i < subSafeAaddr.length - 1; i++) {
            (,, address safeLead,,,) = palmeraModule.getSafeInfo(subSafeAid[i]);
            assertEq(safeLead, address(0));
            assertFalse(
                palmeraModule.isSafeLead(subSafeAid[i], subSafeAaddr[5])
            );
        }
    }
}
