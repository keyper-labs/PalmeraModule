// SPDX-License-Identifier: MIT
// Modified version of OpenZeppelin Contracts v4.4.1 (utils/cryptography/draft-EIP712.sol)

pragma solidity ^0.8.0;

import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";

abstract contract SigningUtils {
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

    function createDigestExecTx(
        bytes32 domainSeparatorGnosis,
        Transaction memory safeTx
    ) public view returns (bytes32) {
        bytes32 digest = _hashTypedDataV4(
            domainSeparatorGnosis,
            keccak256(
                abi.encode(
                    keccak256(
                        "execTransaction(address to,uint256 value,bytes data,Enum.Operation operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures)"
                    ),
                    safeTx.to,
                    safeTx.value,
                    safeTx.data,
                    safeTx.operation,
                    safeTx.safeTxGas,
                    safeTx.baseGas,
                    safeTx.gasPrice,
                    safeTx.gasToken,
                    safeTx.refundReceiver,
                    safeTx.signatures
                )
            )
        );

        return digest;
    }
}
