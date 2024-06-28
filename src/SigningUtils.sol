// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {Enum} from "@safe-contracts/base/Executor.sol";

/// @title SigningUtils
/// @custom:security-contact general@palmeradao.xyz
abstract contract SigningUtils {
    /// @dev Transaction structure
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        bytes signatures;
    }

}
