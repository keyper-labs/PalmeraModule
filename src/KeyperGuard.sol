// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Guard, BaseGuard} from "@safe-contracts/base/GuardManager.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";
import {KeyperModule} from "./KeyperModule.sol";
import {Errors} from "../libraries/Errors.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Constants} from "../libraries/Constants.sol";
import {Events} from "../libraries/Events.sol";

/// @title Keyper Guard
/// @custom:security-contact general@palmeradao.xyz
contract KeyperGuard is BaseGuard {
    KeyperModule keyperModule;

    string public constant NAME = "Keyper Guard";
    string public constant VERSION = "0.2.0";

    constructor(address keyperModuleAddr) {
        if (keyperModuleAddr != address(0)) revert Errors.ZeroAddressProvided();
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
        // TODO: check if the msg.sender, exist or not in the keyperModule,
        // if it does, check if try to disable guard and revert if it does.
        // if it does, check if try to disable the Keyper Module and revert if it does.
        if (keyperModule.isSafeRegistered(msg.sender)) {
            if (!IGnosisSafe(msg.sender).isModuleEnabled(address(keyperModule)))
            {
                revert Errors.CannotKeyperModuleDisable(address(keyperModule));
            }
            if (
                abi.decode(
                    StorageAccessible(msg.sender).getStorageAt(
                        uint256(Constants.GUARD_STORAGE_SLOT), 2
                    ),
                    (address)
                ) != address(this)
            ) {
                revert Errors.CannotDisableKeyperGuard(address(this));
            }
        }
    }
}
