// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Guard, BaseGuard} from "@safe-contracts/base/GuardManager.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {
    PalmeraModule,
    Context,
    Errors,
    Constants,
    IGnosisSafe,
    IGnosisSafeProxy,
    Enum
} from "./PalmeraModule.sol";

/// @title Palmera Guard
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraGuard is BaseGuard, Context {
    PalmeraModule keyperModule;

    string public constant NAME = "Palmera Guard";
    string public constant VERSION = "0.2.0";

    constructor(address keyperModuleAddr) {
        if (keyperModuleAddr == address(0)) revert Errors.ZeroAddressProvided();
        keyperModule = PalmeraModule(keyperModuleAddr);
    }

    function checkTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external {}

    function checkAfterExecution(bytes32, bool) external view {
        address caller = _msgSender();
        // if it does, check if try to disable guard and revert if it does.
        // if it does, check if try to disable the Palmera Module and revert if it does.
        if (keyperModule.isSafeRegistered(caller)) {
            if (!IGnosisSafe(caller).isModuleEnabled(address(keyperModule))) {
                revert Errors.CannotDisablePalmeraModule(address(keyperModule));
            }
            if (
                abi.decode(
                    StorageAccessible(caller).getStorageAt(
                        uint256(Constants.GUARD_STORAGE_SLOT), 2
                    ),
                    (address)
                ) != address(this)
            ) {
                revert Errors.CannotDisablePalmeraGuard(address(this));
            }
        } else {
            if (!keyperModule.isSafe(caller)) {
                bool isSafeLead;
                // Caller is EAO (lead) : check if it has the rights over the target safe
                for (uint256 i = 1; i < keyperModule.indexId(); ++i) {
                    if (keyperModule.isSafeLead(i, caller)) {
                        isSafeLead = true;
                        break;
                    }
                }
                if (!isSafeLead) {
                    revert Errors.NotAuthorizedAsNotSafeLead();
                }
            }
            if (
                (
                    abi.decode(
                        StorageAccessible(caller).getStorageAt(
                            uint256(Constants.GUARD_STORAGE_SLOT), 2
                        ),
                        (address)
                    ) == address(this)
                ) && IGnosisSafe(caller).isModuleEnabled(address(keyperModule))
            ) {
                revert Errors.SafeNotRegistered(caller);
            }
        }
    }
}
