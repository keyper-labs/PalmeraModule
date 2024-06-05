// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {PalmeraRoles} from "../src/PalmeraRoles.sol";
import {Constants} from "../src/libraries/Constants.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";

// Helper contract to test internal method of PalmeraRoles
contract PalmeraRolesHarness is PalmeraRoles(address(0xAAAA)) {
    function exposed_setupRoles(address palmeraModule) external {
        setupRoles(palmeraModule);
    }
}

/// @title PalmeraRolesTest
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraRoleDeployTest is Test {
    PalmeraRolesHarness palmeraRolesHarness;
    address palmeraModule = address(0xAAAA);

    function setUp() public {
        palmeraRolesHarness = new PalmeraRolesHarness();
    }

    /// @notice Test setupRoles Capabilities
    function testSetupRolesCapabilities() public {
        vm.startPrank(palmeraModule);
        palmeraRolesHarness.exposed_setupRoles(palmeraModule);
        vm.stopPrank();

        // Check SAFE_LEAD capabilities
        bool hasSAFELEADCapabilityAddOwner = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD), palmeraModule, Constants.ADD_OWNER
        );
        assertTrue(hasSAFELEADCapabilityAddOwner);
        bool hasSAFELEADCapabilityRemoveOwner = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            palmeraModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSAFELEADCapabilityRemoveOwner);
        bool hasSAFELEADCapabilityExecOnBehalf = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            palmeraModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSAFELEADCapabilityExecOnBehalf);

        // Check SAFE_LEAD_EXEC_ON_BEHALF_ONLY capabilities
        bool hasSAFE_LEAD_EXEC_ON_BEHALF_ONLYCapabilityExecOnBehalf =
        palmeraRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            palmeraModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSAFE_LEAD_EXEC_ON_BEHALF_ONLYCapabilityExecOnBehalf);

        // Check SAFE_LEAD_MODIFY_OWNERS_ONLY capabilities
        bool hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityAddOwner =
        palmeraRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            palmeraModule,
            Constants.ADD_OWNER
        );
        assertTrue(hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityAddOwner);
        bool hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityRemoveOwner =
        palmeraRolesHarness.doesRoleHaveCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            palmeraModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSAFE_LEAD_MODIFY_OWNERS_ONLYCapabilityRemoveOwner);

        // Check SUPER_SAFE capabilities
        bool hasSUPER_SAFECapabilityAddOwner = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE), palmeraModule, Constants.ADD_OWNER
        );
        assertTrue(hasSUPER_SAFECapabilityAddOwner);
        bool hasSUPER_SAFECapabilityRemoveOwner = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.REMOVE_OWNER
        );
        assertTrue(hasSUPER_SAFECapabilityRemoveOwner);
        bool hasSUPER_SAFECapabilityExecOnBehalf = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.EXEC_ON_BEHALF
        );
        assertTrue(hasSUPER_SAFECapabilityExecOnBehalf);
        bool hasSUPER_SAFECapabilityRemoveSafe = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.REMOVE_SAFE
        );
        assertTrue(hasSUPER_SAFECapabilityRemoveSafe);

        // Check ROOT_SAFE capabilities
        bool hasROOT_SAFECapabilityEnableAllowlist = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ENABLE_ALLOWLIST
        );
        assertTrue(hasROOT_SAFECapabilityEnableAllowlist);
        bool hasROOT_SAFECapabilityEnableDenyList = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ENABLE_DENYLIST
        );
        assertTrue(hasROOT_SAFECapabilityEnableDenyList);
        bool hasROOT_SAFECapabilityDisableDenyHelper = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DISABLE_DENY_HELPER
        );
        assertTrue(hasROOT_SAFECapabilityDisableDenyHelper);
        bool hasROOT_SAFECapabilityAddTolist = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ADD_TO_LIST
        );
        assertTrue(hasROOT_SAFECapabilityAddTolist);
        bool hasROOT_SAFECapabilityDropFromlist = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DROP_FROM_LIST
        );
        assertTrue(hasROOT_SAFECapabilityDropFromlist);
        bool hasROOT_SAFECapabilityUpdateSuperSafe = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.UPDATE_SUPER_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityUpdateSuperSafe);
        bool hasROOT_SAFECapabilityCreateRootSafe = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.CREATE_ROOT_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityCreateRootSafe);
        bool hasROOT_SAFECapabilityUpdateDepthTreeLimit = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.UPDATE_DEPTH_TREE_LIMIT
        );
        assertTrue(hasROOT_SAFECapabilityUpdateDepthTreeLimit);
        bool hasROOT_SAFECapabilityDisconnectSafe = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DISCONNECT_SAFE
        );
        assertTrue(hasROOT_SAFECapabilityDisconnectSafe);
        bool hasROOT_SAFECapabilityPromoteRoot = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.PROMOTE_ROOT
        );
        assertTrue(hasROOT_SAFECapabilityPromoteRoot);
        bool hasROOT_SAFECapabilityRemoveWholeTree = palmeraRolesHarness
            .doesRoleHaveCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.REMOVE_WHOLE_TREE
        );
        assertTrue(hasROOT_SAFECapabilityRemoveWholeTree);
    }

    /// @notice Test Set User Roles
    function testSetUserRoles() public {
        vm.startPrank(palmeraModule);
        palmeraRolesHarness.setUserRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD), true
        );
        bool isSafeLead = palmeraRolesHarness.doesUserHaveRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD)
        );
        assertTrue(isSafeLead);
        palmeraRolesHarness.setUserRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD), false
        );
        isSafeLead = palmeraRolesHarness.doesUserHaveRole(
            address(0xCCCC), uint8(DataTypes.Role.SAFE_LEAD)
        );
        assertFalse(isSafeLead);
    }
}
