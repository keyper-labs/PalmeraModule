// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Guard, BaseGuard} from "@safe-contracts/base/GuardManager.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {
    KeyperModule,
    Context,
    Errors,
    Constants,
    ISafe,
    ISafeProxy,
    Enum
} from "./KeyperModule.sol";

/// @title Keyper Guard
/// @custom:security-contact general@palmeradao.xyz
contract KeyperGuard is BaseGuard, Context {
    KeyperModule keyperModule;

    string public constant NAME = "Keyper Guard";
    string public constant VERSION = "0.2.0";

    constructor(address keyperModuleAddr) {
        if (keyperModuleAddr == address(0)) revert Errors.ZeroAddressProvided();
        keyperModule = KeyperModule(keyperModuleAddr);
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
        // if it does, check if try to disable the Keyper Module and revert if it does.
        if (keyperModule.isSafeRegistered(caller)) {
            if (!ISafe(caller).isModuleEnabled(address(keyperModule))) {
                revert Errors.CannotDisableKeyperModule(address(keyperModule));
            }
            if (
                abi.decode(
                    StorageAccessible(caller).getStorageAt(
                        uint256(Constants.GUARD_STORAGE_SLOT), 2
                    ),
                    (address)
                ) != address(this)
            ) {
                revert Errors.CannotDisableKeyperGuard(address(this));
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
        }
    }
}
