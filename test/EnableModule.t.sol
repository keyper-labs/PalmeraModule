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
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        keyperModule = new KeyperModule(masterCopy, safeFactory);
        gnosisHelper.setKeyperModule(address(keyperModule));
    }

    function testEnableKeyperModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled = gnosisHelper.gnosisSafe().isModuleEnabled(
            address(keyperModule)
        );
        assertEq(isKeyperModuleEnabled, true);
    }

    function testNewSafeWithKeyperModule() public {
        // Create new safe with setup called while creating contract
        gnosisHelper.newKeyperSafe(4, 2);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
    }

    function testNewSafeWithKeyperModuleOnSetup() public {
         // Create new safe with setup called while creating contract
        gnosisHelper.newKeyperSafeModuleEnabled(2, 2);
        bool isKeyperModuleEnabled = gnosisHelper.gnosisSafe().isModuleEnabled(
            address(keyperModule)
        );
        assertEq(isKeyperModuleEnabled, true);
    }

    // TODO check why the revert not working in testing but revert is happening without cheatcode
    // function testRevertSetupKeyperModuleTwice() public {
    //      // Create new safe with setup called while creating contract
    //     gnosisHelper.newKeyperSafeModuleEnabled(2, 2);
    //     vm.expectRevert("Keyper module can only by set once");
    //     gnosisHelper.gnosisSafe().enableKeyperModule(address(0xa1a1));
    // }
}
