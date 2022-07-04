// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
// import "forge-std/Console.sol";

import "../script/DeploySafe.t.sol";
import "../src/SigningUtils.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract enableModule is Test, SigningUtils {
    DeploySafe deploySafe;
    Transaction mockTx;
    GnosisSafe gnosisSafe;
    KeyperModule keyperModule;
    uint256[] privateKeyOwners;

    // address[] owners;

    // Deploy safe proxy
    // Setup new safe
    function setUp() public {
        deploySafe = new DeploySafe();
        deploySafe.run();
        address gnosisSafeProxy = deploySafe.getProxyAddress();
        gnosisSafe = GnosisSafe(payable(address(gnosisSafeProxy)));

        privateKeyOwners = new uint256[](3);
        privateKeyOwners[0] = 0xA11CE;
        privateKeyOwners[1] = 0xB11CD;
        privateKeyOwners[2] = 0xD11CD;

        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);

        bytes memory emptyData;

        gnosisSafe.setup(
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        mockTx = Transaction(
            address(gnosisSafe),
            0 gwei,
            emptyData,
            Enum.Operation(0),
            0,
            0,
            0,
            address(0),
            address(0),
            emptyData
        );
    }

    function testTransferFundsSafe() public {
        // Send funds to safe
        vm.deal(address(gnosisSafe), 2 ether);
        // Create encoded tx to be signed
        uint256 nonce = gnosisSafe.nonce();
        mockTx.value = 0.5 ether;
        bytes32 transferSafeTx = createSafeTxData(mockTx, nonce);
        // Sign encoded tx with 1 owner
        uint256[] memory privateKeyOwner = new uint256[](1);
        privateKeyOwner[0] = privateKeyOwners[0];

        bytes memory signatures = signDigestTx(
            privateKeyOwner,
            transferSafeTx
        );
        // Exec tx
        bool result = gnosisSafe.execTransaction(
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

        assertEq(address(gnosisSafe).balance, 1.5 ether);
    }

    function testEnableKeyperModule() public {
        keyperModule = new KeyperModule();

        // Create enable calldata
        bytes memory data = abi.encodeWithSignature(
            "enableModule(address)",
            address(keyperModule)
        );
        mockTx.data = data;
        // Create encoded tx to be signed
        uint256 nonce = gnosisSafe.nonce();
        bytes32 enableModuleSafeTx = createSafeTxData(mockTx, nonce);
        // Sign encoded tx with 1 owner
        uint256[] memory privateKeyOwner = new uint256[](1);
        privateKeyOwner[0] = privateKeyOwners[0];

        bytes memory signatures = signDigestTx(
            privateKeyOwner,
            enableModuleSafeTx
        );
        // Exec tx
        bool result = gnosisSafe.execTransaction(
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

        // Verify module has been enabled
        bool isKeyperModuleEnabled = gnosisSafe.isModuleEnabled(
            address(keyperModule)
        );
        assertEq(isKeyperModuleEnabled, true);
    }

    function createSafeTxData(Transaction memory safeTx, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        bytes32 dataHashed = this.callGetTransactionHash(
            safeTx.to,
            safeTx.value,
            safeTx.data,
            safeTx.operation,
            safeTx.safeTxGas,
            safeTx.baseGas,
            safeTx.gasPrice,
            safeTx.gasToken,
            safeTx.refundReceiver,
            nonce
        );

        return dataHashed;
    }

    function callGetTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32) {
        bytes32 encodedTx = gnosisSafe.getTransactionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            _nonce
        );

        return encodedTx;
    }

    function signDigestTx(uint256[] memory _privateKeyOwners, bytes32 digest)
        public
        returns (bytes memory)
    {
        bytes memory signatures;
        for (uint256 i = 0; i < _privateKeyOwners.length; i++) {
            address add = vm.addr(_privateKeyOwners[i]);
            console.log("signed by: ", add);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                _privateKeyOwners[i],
                digest
            );
            signatures = abi.encodePacked(signatures, r, s, v);
        }

        return signatures;
    }
}
