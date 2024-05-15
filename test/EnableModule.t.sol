// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableModule is Test {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    address gnosisSafeAddr;

    /// @notice Set up the environment
    function setUp() public {
        // Init new safe
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();
        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        keyperModule = new KeyperModule(
            masterCopy, safeFactory, rolesAuthority, maxTreeDepth
        );
        gnosisHelper.setKeyperModule(address(keyperModule));
    }

    /// @notice Test enable Keyper Module
    function testEnableKeyperModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    /// @notice Test disable Keyper Module
    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        gnosisHelper.newKeyperSafe(4, 2);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
    }
}
