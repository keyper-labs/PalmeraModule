// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {KeyperModule, Errors, Constants} from "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableGuard is Test {
    KeyperModule keyperModule;
    KeyperGuard keyperGuard;
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
        keyperGuard = new KeyperGuard(address(keyperModule));
        safeHelper.setKeyperModule(address(keyperModule));
        safeHelper.setKeyperGuard(address(keyperGuard));
    }

    function testEnableKeyperModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            safeHelper.safe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testEnableKeyperGuard() public {
        bool result = safeHelper.enableGuardTx(safeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        address guardAddress = abi.decode(
            StorageAccessible(safeAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }
}
