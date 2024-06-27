// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
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

    // /**
    //  * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
    //  * function returns the hash of the fully encoded EIP712 message for this domain.
    //  *
    //  * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
    //  *
    //  * ```solidity
    //  * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
    //  *     keccak256("Mail(address to,string contents)"),
    //  *     mailTo,
    //  *     keccak256(bytes(mailContents))
    //  * )));
    //  * address signer = ECDSA.recover(digest, signature);
    //  * ```
    //  */
    // function _hashTypedDataV4(bytes32 domainSeparator, bytes32 structHash)
    //     internal
    //     view
    //     virtual
    //     returns (bytes32)
    // {
    //     return ECDSA.toTypedDataHash(domainSeparator, structHash);
    // }

    // /**
    //  * @dev Given a transaction, it creates a hash of the transaction that can be signed
    //  * @param domainSeparatorSafe Hash of the Safe domain separator
    //  * @param safeTx Safe transaction
    //  * @return Hash of the transaction
    //  */
    // function createDigestExecTx(
    //     bytes32 domainSeparatorSafe,
    //     Transaction memory safeTx
    // ) public view returns (bytes32) {
    //     bytes32 digest = _hashTypedDataV4(
    //         domainSeparatorSafe,
    //         keccak256(
    //             abi.encode(
    //                 keccak256(
    //                     "execTransaction(address to,uint256 value,bytes data,Enum.Operation operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures)"
    //                 ),
    //                 safeTx.to,
    //                 safeTx.value,
    //                 safeTx.data,
    //                 safeTx.operation,
    //                 safeTx.safeTxGas,
    //                 safeTx.baseGas,
    //                 safeTx.gasPrice,
    //                 safeTx.gasToken,
    //                 safeTx.refundReceiver,
    //                 safeTx.signatures
    //             )
    //         )
    //     );

    //     return digest;
    // }
}
