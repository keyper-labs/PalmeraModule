// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/SignDigestHelper.t.sol";
import "./helpers/GnosisSafeHelper.t.sol";

/// @title TestDeploySafe
/// @custom:security-contact general@palmeradao.xyz
contract TestDeploySafe is Test, SigningUtils, SignDigestHelper {
    GnosisSafeHelper gnosisHelper;
    address safeAddr;

    // Init new safe
    function setUp() public {
        gnosisHelper = new GnosisSafeHelper();
        safeAddr = gnosisHelper.setupSafeEnv();
    }

    function testTransferFundsSafe() public {
        bytes memory emptyData;

        Transaction memory mockTx = Transaction(
            address(0xaa),
            0.5 ether,
            emptyData,
            Enum.Operation(0),
            0,
            0,
            0,
            address(0),
            address(0),
            emptyData
        );

        // Send funds to safe
        vm.deal(safeAddr, 2 ether);
        // Create encoded tx to be signed
        uint256 nonce = gnosisHelper.safe().nonce();
        bytes32 transferSafeTx = gnosisHelper.createSafeTxHash(mockTx, nonce);
        // Sign encoded tx with 1 owner
        uint256[] memory privateKeyOwner = new uint256[](1);
        privateKeyOwner[0] = gnosisHelper.privateKeyOwners(0);

        bytes memory signatures = signDigestTx(privateKeyOwner, transferSafeTx);
        // Exec tx
        bool result = gnosisHelper.safe().execTransaction(
            mockTx.to,
            mockTx.value,
            mockTx.data,
            mockTx.operation,
            mockTx.safeTxGas,
            mockTx.baseGas,
            mockTx.gasPrice,
            mockTx.gasToken,
            payable(address(0)),
            signatures
        );
        assertEq(result, true);
        assertEq(safeAddr.balance, 1.5 ether);
    }
}
