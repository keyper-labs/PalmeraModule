// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

// Helper contract to test internal method of KeyperRoles
contract KeyperRolesHarness is KeyperRoles(address(0xAAAA)) {
    function exposed_setupRoles(address keyperModule) external {
        setupRoles(keyperModule);
    }
}

contract KeyperRoleDeployTest is Test {
    KeyperRolesHarness keyperRolesHarness;
    address keyperModule = address(0xAAAA);

    function setUp() public {
        keyperRolesHarness = new KeyperRolesHarness();
    }

    function testSetupRolesCapabilities() public {
        vm.startPrank(keyperModule);
        keyperRolesHarness.exposed_setupRoles(keyperModule);
        vm.stopPrank();

        // Check SAFE_LEAD capabilities
        bool hasSAFELEADCapabilityAddOwner = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD), keyperModule, Constants.ADD_OWNER
        );
        assertTrue(hasSAFELEADCapabilityAddOwner);
        bool hasSAFELEADCapabilityRemoveOwner = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            keyperModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSAFELEADCapabilityRemoveOwner);
        bool hasSAFELEADCapabilityExecOnBehalf = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            keyperModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSAFELEADCapabilityExecOnBehalf);

        // Check SAFE_LEAD_EXEC_ON_BEHALF_ONLY capabilities
        bool hasSAFE_LEAD_EXEC_ON_BEHALF_ONLYCapabilityExecOnBehalf =
        keyperRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            keyperModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSAFE_LEAD_EXEC_ON_BEHALF_ONLYCapabilityExecOnBehalf);

        // Check SAFE_LEAD_MODIFY_OWNERS_ONLY capabilities
        bool hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityAddOwner =
        keyperRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            Constants.ADD_OWNER
        );
        assertTrue(hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityAddOwner);
        bool hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityRemoveOwner =
        keyperRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityRemoveOwner);

        // Check SUPER_SAFE capabilities
        bool hasSUPER_SAFECapabilityAddOwner = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE), keyperModule, Constants.ADD_OWNER
        );
        assertTrue(hasSUPER_SAFECapabilityAddOwner);
        bool hasSUPER_SAFECapabilityRemoveOwner = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSUPER_SAFECapabilityRemoveOwner);
        bool hasSUPER_SAFECapabilityExecOnBehalf = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSUPER_SAFECapabilityExecOnBehalf);
        bool hasSUPER_SAFECapabilityRemoveSquad = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.REMOVE_SQUAD
        );
        assertTrue(hasSUPER_SAFECapabilityRemoveSquad);

        // Check ROOT_SAFE capabilities
        bool hasROOT_SAFECapabilityEnableAllowlist = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ENABLE_ALLOWLIST
        );
        assertTrue(hasROOT_SAFECapabilityEnableAllowlist);
        bool hasROOT_SAFECapabilityEnableDenyList = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ENABLE_DENYLIST
        );
        assertTrue(hasROOT_SAFECapabilityEnableDenyList);
        bool hasROOT_SAFECapabilityDisableDenyHelper = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DISABLE_DENY_HELPER
        );
        assertTrue(hasROOT_SAFECapabilityDisableDenyHelper);
        bool hasROOT_SAFECapabilityAddTolist = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE), keyperModule, Constants.ADD_TO_LIST
        );
        assertTrue(hasROOT_SAFECapabilityAddTolist);
        bool hasROOT_SAFECapabilityDropFromlist = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DROP_FROM_LIST
        );
        assertTrue(hasROOT_SAFECapabilityDropFromlist);
        bool hasROOT_SAFECapabilityUpdateSuperSafe = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.UPDATE_SUPER_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityUpdateSuperSafe);
        bool hasROOT_SAFECapabilityCreateRootSafe = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.CREATE_ROOT_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityCreateRootSafe);
        bool hasROOT_SAFECapabilityUpdateDepthTreeLimit = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.UPDATE_DEPTH_TREE_LIMIT
        );
        assertTrue(hasROOT_SAFECapabilityUpdateDepthTreeLimit);
        bool hasROOT_SAFECapabilityDisconnectSafe = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DISCONNECT_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityDisconnectSafe);
        bool hasROOT_SAFECapabilityPromoteRoot = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.PROMOTE_ROOT
        );
        assertTrue(hasROOT_SAFECapabilityPromoteRoot);
        bool hasROOT_SAFECapabilityRemoveWholeTree = keyperRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.REMOVE_WHOLE_TREE
        );
        assertTrue(hasROOT_SAFECapabilityRemoveWholeTree);
    }

    function testSetUserRoles() public {
        vm.startPrank(keyperModule);
        keyperRolesHarness.setUserRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD), true
        );
        bool isSafeLead = keyperRolesHarness.doesUserHaveRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD)
        );
        assertTrue(isSafeLead);
        keyperRolesHarness.setUserRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD), false
        );
        isSafeLead = keyperRolesHarness.doesUserHaveRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD)
        );
        assertFalse(isSafeLead);
    }
}
