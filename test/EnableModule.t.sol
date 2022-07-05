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
        gnosisSafeAddr = gnosisHelper.setupSafe();
        // Init KeyperModule
        keyperModule = new KeyperModule();
    }

    function testEnableKeyperModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr, address(keyperModule));
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled = gnosisHelper.gnosisSafe().isModuleEnabled(
            address(keyperModule)
        );
        assertEq(isKeyperModuleEnabled, true);
    }

    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        address keyperSafe = gnosisHelper.newKeyperSafe(4,2);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
        // Enable keyper module
        bool result = gnosisHelper.enableModuleTx(keyperSafe, address(keyperModule));
        assertEq(result, true);
    }
}
