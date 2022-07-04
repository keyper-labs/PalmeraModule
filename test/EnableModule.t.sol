// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./SignDigestHelper.t.sol";
import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

contract TestEnableModule is Test, SigningUtils, SignDigestHelper {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    address gnosisSafeAddr;

    function setUp() public {
        // Init new safe
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafe();
        // Init KeyperModule
        keyperModule = new KeyperModule();
    }

    function testEnableKeyperModule() public {
        // Create enableModule calldata
        bytes memory data = abi.encodeWithSignature(
            "enableModule(address)",
            address(keyperModule)
        );

        bytes memory emptyData;
        // Create enable module safe tx
        Transaction memory mockTx = Transaction(
            gnosisSafeAddr,
            0 gwei,
            data,
            Enum.Operation(0),
            0,
            0,
            0,
            address(0),
            address(0),
            emptyData
        );

        // Create encoded tx to be signed
        uint256 nonce = gnosisHelper.gnosisSafe().nonce();
        bytes32 enableModuleSafeTx = gnosisHelper.createSafeTxHash(mockTx, nonce);
        // Sign encoded tx with 1 owner
        uint256[] memory privateKeyOwner = new uint256[](1);
        privateKeyOwner[0] = gnosisHelper.privateKeyOwners(0);

        bytes memory signatures = signDigestTx(
            privateKeyOwner,
            enableModuleSafeTx
        );
        // Exec tx
        bool result = gnosisHelper.gnosisSafe().execTransaction(
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
        // Verify module has been enabled
        bool isKeyperModuleEnabled = gnosisHelper.gnosisSafe().isModuleEnabled(
            address(keyperModule)
        );
        assertEq(isKeyperModuleEnabled, true);
    }
}
