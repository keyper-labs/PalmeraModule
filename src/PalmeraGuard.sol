// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {BaseGuard} from "@safe-contracts/base/GuardManager.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {
    PalmeraModule,
    Context,
    Errors,
    Constants,
    ISafe,
    Enum
} from "./PalmeraModule.sol";

/// @title Palmera Guard
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraGuard is BaseGuard, Context {
    PalmeraModule immutable palmeraModule;
    /// @notice Name of the Guard
    string public constant NAME = "Palmera Guard";
    /// @notice Version of the Guard
    string public constant VERSION = "0.2.0";

    constructor(address payable palmeraModuleAddr) {
        if (palmeraModuleAddr == address(0)) {
            revert Errors.ZeroAddressProvided();
        }
        palmeraModule = PalmeraModule(palmeraModuleAddr);
    }

    /// @notice Fallback function: called when someone sends ETH or calls a function that does not exist
    fallback() external {
        revert Errors.NotPermittedReceiveEther();
    }

    /// @notice Receive function: called when someone sends ETH to the contract without data
    receive() external payable {
        revert Errors.NotPermittedReceiveEther();
    }

    /// @notice Instance of Base Guard Safe Interface
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

    /// @notice Instance of Base Guard Safe Interface
    /// @dev Check if the transaction is allowed, based of have the rights to execute it.
    function checkAfterExecution(bytes32, bool) external view {
        address caller = _msgSender();
        // if it does, check if try to disable guard and revert if it does.
        // if it does, check if try to disable the Palmera Module and revert if it does.
        if (palmeraModule.isSafeRegistered(caller)) {
            if (!ISafe(caller).isModuleEnabled(address(palmeraModule))) {
                revert Errors.CannotDisablePalmeraModule(address(palmeraModule));
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
            if (!palmeraModule.isSafe(caller)) {
                bool isSafeLead;
                // Caller is EAO (lead) : check if it has the rights over the target safe
                for (uint256 i = 1; i < palmeraModule.indexId();) {
                    if (palmeraModule.isSafeLead(i, caller)) {
                        isSafeLead = true;
                        break;
                    }
                    unchecked {
                        ++i;
                    }
                }
                if (!isSafeLead) {
                    revert Errors.NotAuthorizedAsNotSafeLead();
                }
            }
        }
    }
}
