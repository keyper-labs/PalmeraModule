// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./helpers/SafeHelper.t.sol";
import {KeyperModule, Errors, Constants} from "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableGuard is Test {
    KeyperModule keyperModule;
    KeyperGuard keyperGuard;
    SafeHelper safeHelper;
    address safeAddr;

    /// @notice Set up the environment for testing
    function setUp() public {
        // Init new safe
        safeHelper = new SafeHelper();
        safeAddr = safeHelper.setupSafeEnv();
        // Init KeyperModule
        address masterCopy = safeHelper.safeMasterCopy();
        address safeFactory = address(safeHelper.safeFactory());
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        keyperModule = new KeyperModule(
            masterCopy, safeFactory, rolesAuthority, maxTreeDepth
        );
        keyperGuard = new KeyperGuard(address(keyperModule));
        safeHelper.setKeyperModule(address(keyperModule));
        safeHelper.setKeyperGuard(address(keyperGuard));
    }

    /// @notice Test enabling the KeyperModule
    function testEnableKeyperModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    /// @notice Test enabling the KeyperGuard
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
