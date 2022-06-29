// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/utils/cryptography/draft-EIP712.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";

contract TestSigningSafeTx is Test, EIP712("TODO-CheckSAFETX", "1.3") {
    Transaction mockTx;

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

    function setUp() public {
        mockTx = Transaction(
            address(0x1),
            0 gwei,
            "0x",
            Enum.Operation(1),
            5 gwei,
            5 gwei,
            5 gwei,
            address(0),
            address(0),
            "0x"
        );
    }

    function testCreateSignature() public {}

    function createDigestExecTx(Transaction memory safeTx)
        private
        returns (bytes32)
    {
        bytes32 digest = _hashTypedDataV4(
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
