// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import "./helpers/DeployHelper.t.sol";
import {MockedContract} from "./mocks/MockedContract.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract KeyperRolesTest is Test, DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts();
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

        KeyperModule keyperModule = KeyperModule(keyperModuleAddr);
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
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address userEOALead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userEOALead, safeGroupA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userEOALead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeGroupA1, userEOALead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> GroupA, Hierarchy related to caller -> N/A
    function testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_SAFE() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address safeLead = gnosisHelper.newKeyperSafe(4, 2);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        vm.startPrank(rootAddr);

        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeLead, safeGroupA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeGroupA1, safeLead), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> GroupA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        keyperModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeGroupA1, true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> groupA
    // Target Info: Type-> EOA, Name -> user, Hierarchy related to caller -> N/A
    function testCannot_SUPER_SAFE_SetRole_SAFE_LEAD_to_EAO() public {
        (, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);

        address user = address(0xABCDE);

        vm.startPrank(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA1Addr
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, groupA1Id, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> root
    // Target Info: Type-> SAFE, Name -> groupA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_SAFE() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupAId) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupAddr = keyperModule.getGroupSafeAddress(groupA1Id);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(
            DataTypes.Role.SUPER_SAFE, groupAddr, subGroupAId, true
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> GroupA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_EAO() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(DataTypes.Role.SUPER_SAFE, user, safeGroupA1, true);
    }

    //  Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> EOA, Name -> GroupA, Hierarchy related to caller -> N/A
    function testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EOA_DifferentTree_Safe()
        public
    {
        (uint256 rootIdA,,, uint256 groupBId) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootIdA);
        address user = address(0xABCDE);
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorizedSetRoleAnotherTree.selector
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, groupBId, true);
    }
}
