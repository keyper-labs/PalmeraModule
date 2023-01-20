// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableModule is Test {
    KeyperModule keyperModule;
    GnosisSafeHelper safeHelper;
    address safeAddr;

    function setUp() public {
        // Init new safe
        safeHelper = new GnosisSafeHelper();
        safeAddr = safeHelper.setupSafeEnv();
        // Init KeyperModule
        address masterCopy = safeHelper.gnosisMasterCopy();
        address safeFactory = address(safeHelper.safeFactory());
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        keyperModule = new KeyperModule(
            masterCopy,
            safeFactory,
            rolesAuthority,
            maxTreeDepth
        );
        safeHelper.setKeyperModule(address(keyperModule));
    }

    function testEnableKeyperModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            safeHelper.safe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        safeHelper.newKeyperSafe(4, 2);
        address[] memory owners = safeHelper.safe().getOwners();
        assertEq(owners.length, 4);
        assertEq(safeHelper.safe().getThreshold(), 2);
    }
}
