// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

contract KeyperRolesTest is DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    function testCan_KeyperModule_Setup_RoleContract() public {
        // Check KeyperModule has role capabilites
        assertEq(
            keyperRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                keyperModuleAddr,
                Constants.ADD_OWNER
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                keyperModuleAddr,
                Constants.REMOVE_OWNER
            ),
            true
        );
        // Check roleAuthority owner is set to keyper module
        assertEq(keyperRolesContract.owner(), keyperModuleAddr);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    function testCan_ROOT_SAFE_SetRole_ROOT_SAFE_When_RegisterOrg() public {
        address org1 = gnosisSafeAddr;
        vm.startPrank(org1);

        keyperModule.registerOrg(orgName);
        // Check Role
        assertEq(
            keyperRolesContract.doesRoleHaveCapability(
                uint8(DataTypes.Role.ROOT_SAFE),
                address(keyperModule),
                Constants.ROLE_ASSIGMENT
            ),
            true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> EAO, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address userEOALead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userEOALead, safeSquadA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userEOALead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeSquadA1, userEOALead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_SAFE() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address safeLead = gnosisHelper.newKeyperSafe(4, 2);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        vm.startPrank(rootAddr);

        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeLead, safeSquadA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeSquadA1, safeLead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        keyperModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeSquadA1, true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> squadA
    // Target Info: Type-> EOA, Name -> user, Hierarchy related to caller -> N/A
    function testCannot_SUPER_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        address user = address(0xABCDE);

        vm.startPrank(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA1Addr
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, squadA1Id, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> root
    // Target Info: Type-> SAFE, Name -> squadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 subSquadAId,,) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadAddr = keyperModule.getSquadSafeAddress(squadA1Id);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(
            DataTypes.Role.SUPER_SAFE, squadAddr, subSquadAId, true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(DataTypes.Role.SUPER_SAFE, user, safeSquadA1, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> SquadA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EOA_DifferentTree_Safe()
        public
    {
        (uint256 rootIdA,,, uint256 squadBId) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootIdA);
        address user = address(0xABCDE);
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorizedSetRoleAnotherTree.selector
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, squadBId, true);
    }
}
