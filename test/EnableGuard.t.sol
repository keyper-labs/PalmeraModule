// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {Errors} from "../libraries/Errors.sol";
import {Constants} from "../libraries/Constants.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableGuard is Test {
    KeyperModule keyperModule;
    KeyperGuard keyperGuard;
    GnosisSafeHelper gnosisHelper;
    address gnosisSafeAddr;

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
            masterCopy,
            safeFactory,
            rolesAuthority,
            maxTreeDepth
        );
        keyperGuard = new KeyperGuard(address(keyperModule));
        gnosisHelper.setKeyperModule(address(keyperModule));
        gnosisHelper.setKeyperGuard(address(keyperGuard));
    }

    function testEnableKeyperModule() public {
        bool result = gnosisHelper.enableModuleTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testEnableKeyperGuard() public {
        bool result = gnosisHelper.enableGuardTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        if (
            abi.decode(
                StorageAccessible(gnosisSafeAddr).getStorageAt(
                    uint256(Constants.GUARD_STORAGE_SLOT), 2
                ),
                (address)
            ) != address(keyperGuard)
        ) {
            revert Errors.CannotEnableKeyperGuard(address(keyperGuard));
        }
    }
}
