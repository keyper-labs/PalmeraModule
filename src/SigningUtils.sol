// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {Enum} from "@safe-contracts/libraries/Enum.sol";

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

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 domainSeparator, bytes32 structHash)
        internal
        view
        virtual
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }

    /**
     * @dev Given a transaction, it creates a hash of the transaction that can be signed
     * @param domainSeparatorSafe Hash of the Safe domain separator
     * @param safeTx Safe transaction
     * @return Hash of the transaction
     */
    function createDigestExecTx(
        bytes32 domainSeparatorSafe,
        Transaction memory safeTx
    ) public view returns (bytes32) {
        bytes32 digest;

        // Using memory-safe assembly to avoid stack too deep error
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            // Split the long string literal into multiple parts of at most 32 bytes each
            let part1 := keccak256(add("execTransaction(address ", 0), 26)
            let part2 := keccak256(add("to,uint256 value,bytes ", 0), 23)
            let part3 := keccak256(add("data,Enum.Operation ", 0), 22)
            let part4 := keccak256(add("operation,uint256 ", 0), 18)
            let part5 := keccak256(add("safeTxGas,uint256 ", 0), 18)
            let part6 := keccak256(add("baseGas,uint256 ", 0), 16)
            let part7 := keccak256(add("gasPrice,address ", 0), 18)
            let part8 := keccak256(add("gasToken,address ", 0), 18)
            let part9 := keccak256(add("refundReceiver,bytes ", 0), 23)
            let part10 := keccak256(add("signatures)", 0), 11)

            // Combine the hashed parts
            mstore(ptr, part1)
            mstore(add(ptr, 0x20), part2)
            mstore(add(ptr, 0x40), part3)
            mstore(add(ptr, 0x60), part4)
            mstore(add(ptr, 0x80), part5)
            mstore(add(ptr, 0xa0), part6)
            mstore(add(ptr, 0xc0), part7)
            mstore(add(ptr, 0xe0), part8)
            mstore(add(ptr, 0x100), part9)
            mstore(add(ptr, 0x120), part10)
            let functionSignature := keccak256(ptr, 0x140)
            mstore(ptr, functionSignature)

            // Hash the transaction fields
            mstore(add(ptr, 0x20), mload(add(safeTx, 0x20))) // to
            mstore(add(ptr, 0x40), mload(add(safeTx, 0x40))) // value
            mstore(
                add(ptr, 0x60),
                keccak256(
                    add(mload(add(safeTx, 0x60)), 0x20),
                    mload(mload(add(safeTx, 0x60)))
                )
            ) // data
            mstore(add(ptr, 0x80), mload(add(safeTx, 0x80))) // operation
            mstore(add(ptr, 0xa0), mload(add(safeTx, 0xa0))) // safeTxGas
            mstore(add(ptr, 0xc0), mload(add(safeTx, 0xc0))) // baseGas
            mstore(add(ptr, 0xe0), mload(add(safeTx, 0xe0))) // gasPrice
            mstore(add(ptr, 0x100), mload(add(safeTx, 0x100))) // gasToken
            mstore(add(ptr, 0x120), mload(add(safeTx, 0x120))) // refundReceiver
            mstore(
                add(ptr, 0x140),
                keccak256(
                    add(mload(add(safeTx, 0x140)), 0x20),
                    mload(mload(add(safeTx, 0x140)))
                )
            ) // signatures

            // Calculate the digest
            digest := keccak256(ptr, 0x160)
        }

        digest = _hashTypedDataV4(domainSeparatorSafe, digest);

        return digest;
    }
}
