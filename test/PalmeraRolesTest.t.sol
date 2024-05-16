// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

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
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address userEOALead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, userEOALead, safeSquadA1, true
        );

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                userEOALead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(palmeraModule.isSafeLead(safeSquadA1, userEOALead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_SAFE() public {
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address safeLead = safeHelper.newPalmeraSafe(4, 2);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        vm.startPrank(rootAddr);

        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeLead, safeSquadA1, true
        );

        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(palmeraModule.isSafeLead(safeSquadA1, safeLead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        palmeraModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeSquadA1, true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> squadA
    // Target Info: Type-> EOA, Name -> user, Hierarchy related to caller -> N/A
    function testCannot_SUPER_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (, uint256 squadA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address squadA1Addr = palmeraModule.getSquadSafeAddress(squadA1Id);

        address user = address(0xABCDE);

        vm.startPrank(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA1Addr)
        );
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, user, squadA1Id, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> root
    // Target Info: Type-> SAFE, Name -> squadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadAId,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address squadAddr = palmeraModule.getSquadSafeAddress(squadA1Id);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        palmeraModule.setRole(
            DataTypes.Role.SUPER_SAFE, squadAddr, subSquadAId, true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        palmeraModule.setRole(
            DataTypes.Role.SUPER_SAFE, user, safeSquadA1, true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EOA_DifferentTree_Safe()
        public
    {
        (uint256 rootIdA,,, uint256 squadBId) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootIdA);
        address user = address(0xABCDE);
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorizedSetRoleAnotherTree.selector
            )
        );
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, user, squadBId, true);
    }
}
