// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

contract TestEnableModule is Test {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    address gnosisSafeAddr;

    function setUp() public {
        // Init new safe
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();
        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        // TODO Init KeyperRoles properly
        address rolesAuthority = address(0xBEEF);
        keyperModule = new KeyperModule(
            masterCopy,
            safeFactory,
            rolesAuthority
        );
        gnosisHelper.setKeyperModule(address(keyperModule));
    }

    function testEnableKeyperModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        gnosisHelper.newKeyperSafe(4, 2);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
    }
}
