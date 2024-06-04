// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "./helpers/SafeHelper.t.sol";
import {PalmeraModule} from "../src/PalmeraModule.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableModule is Test {
    PalmeraModule palmeraModule;
    SafeHelper safeHelper;
    address safeAddr;

    /// @notice Set up the environment
    function setUp() public {
        // Init new safe
        safeHelper = new SafeHelper();
        safeAddr = safeHelper.setupSafeEnv();
        // Init PalmeraModule
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        palmeraModule = new PalmeraModule(rolesAuthority, maxTreeDepth);
        safeHelper.setPalmeraModule(address(palmeraModule));
    }

    /// @notice Test enable Palmera Module
    function testEnablePalmeraModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    /// @notice Test disable Palmera Module
    function testNewSafeWithPalmeraModule() public {
        // Create new safe with setup called while creating contract
        safeHelper.newPalmeraSafe(4, 2);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        assertEq(owners.length, 4);
        assertEq(safeHelper.safeWallet().getThreshold(), 2);
    }
}
