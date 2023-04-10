// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {PalmeraModule, Errors, Constants} from "../src/PalmeraModule.sol";
import {PalmeraGuard} from "../src/PalmeraGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableGuard is Test {
    PalmeraModule keyperModule;
    PalmeraGuard keyperGuard;
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
        keyperGuard = new PalmeraGuard(address(keyperModule));
        gnosisHelper.setPalmeraModule(address(keyperModule));
        gnosisHelper.setPalmeraGuard(address(keyperGuard));
    }

    function testEnablePalmeraModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    function testEnablePalmeraGuard() public {
        bool result = gnosisHelper.enableGuardTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        address guardAddress = abi.decode(
            StorageAccessible(gnosisSafeAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }
}
