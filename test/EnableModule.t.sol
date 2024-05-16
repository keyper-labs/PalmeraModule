// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/SafeHelper.t.sol";
import {PalmeraModule} from "../src/PalmeraModule.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableModule is Test {
    PalmeraModule keyperModule;
    SafeHelper safeHelper;
    address safeAddr;

    /// @notice Set up the environment
    function setUp() public {
        // Init new safe
        safeHelper = new SafeHelper();
        safeAddr = safeHelper.setupSafeEnv();
        // Init PalmeraModule
        address masterCopy = safeHelper.safeMasterCopy();
        address safeFactory = address(safeHelper.safeFactory());
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        keyperModule = new PalmeraModule(
            masterCopy, safeFactory, rolesAuthority, maxTreeDepth
        );
        safeHelper.setKeyperModule(address(keyperModule));
    }

    /// @notice Test enable Keyper Module
    function testEnableKeyperModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    /// @notice Test disable Keyper Module
    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        safeHelper.newKeyperSafe(4, 2);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        assertEq(owners.length, 4);
        assertEq(safeHelper.safeWallet().getThreshold(), 2);
    }
}
