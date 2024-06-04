// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "./helpers/SafeHelper.t.sol";
import {PalmeraModule, Errors, Constants} from "../src/PalmeraModule.sol";
import {PalmeraGuard} from "../src/PalmeraGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title TestEnableModule
/// @custom:security-contact general@palmeradao.xyz
contract TestEnableGuard is Test {
    PalmeraModule palmeraModule;
    PalmeraGuard palmeraGuard;
    SafeHelper safeHelper;
    address safeAddr;

    /// @notice Set up the environment for testing
    function setUp() public {
        // Init new safe
        safeHelper = new SafeHelper();
        safeAddr = safeHelper.setupSafeEnv();
        // Init PalmeraModule
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        palmeraModule = new PalmeraModule(rolesAuthority, maxTreeDepth);
        palmeraGuard = new PalmeraGuard(payable(address(palmeraModule)));
        safeHelper.setPalmeraModule(address(palmeraModule));
        safeHelper.setPalmeraGuard(address(palmeraGuard));
    }

    /// @notice Test enabling the PalmeraModule
    function testEnablePalmeraModule() public {
        bool result = safeHelper.enableModuleTx(safeAddr);
        assertEq(result, true);
        // Verify module has been enabled
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    /// @notice Test enabling the PalmeraGuard
    function testEnablePalmeraGuard() public {
        bool result = safeHelper.enableGuardTx(safeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        address guardAddress = abi.decode(
            StorageAccessible(safeAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(palmeraGuard));
    }
}
