// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {PalmeraModule} from "../src/PalmeraModule.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableModule is Test {
    PalmeraModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    address gnosisSafeAddr;

    function setUp() public {
        // Init new safe
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();
        // Init PalmeraModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        keyperModule = new PalmeraModule(
            masterCopy,
            safeFactory,
            rolesAuthority,
            maxTreeDepth
        );
        gnosisHelper.setPalmeraModule(address(keyperModule));
    }

    function testEnablePalmeraModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    function testNewSafeWithPalmeraModule() public {
        // Create new safe with setup called while creating contract
        gnosisHelper.newPalmeraSafe(4, 2);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
    }
}
