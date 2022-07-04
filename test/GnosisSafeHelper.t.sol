pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "../script/DeploySafe.t.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract GnosisSafeHelper is Test, SigningUtils {
    GnosisSafe public gnosisSafe;
    DeploySafe public deploySafe;
    uint256[] public privateKeyOwners;

    // Setup gnosis safe with 3 owners, 1 threshold
    // TODO: make this function flexible
    function setupSafe() public returns (address) {
        deploySafe = new DeploySafe();
        deploySafe.run();
        address gnosisSafeProxy = deploySafe.getProxyAddress();
        gnosisSafe = GnosisSafe(payable(address(gnosisSafeProxy)));
        initOnwers();

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

        return address(gnosisSafe);
    }

    // TODO grab the pk from env file
    function initOnwers() private {
        privateKeyOwners = new uint256[](5);
        privateKeyOwners[0] = 0xA11CE;
        privateKeyOwners[1] = 0xB11CD;
        privateKeyOwners[2] = 0xD11CD;
        privateKeyOwners[3] = 0xE11CD;
        privateKeyOwners[4] = 0xF11CD;
    }

    function newKeyperSafe(uint256 numberOwners, uint256 threshold) public returns (address) {
        require(privateKeyOwners.length >= numberOwners, "not enough initialized owners");
        address[] memory owners = new address[](numberOwners);
        for(uint256 i = 0; i< numberOwners; i++) {
            owners[i] = vm.addr(privateKeyOwners[i]);
        }
        bytes memory emptyData;
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        address gnosisSafeProxy = deploySafe.newSafeProxy(initializer);
        gnosisSafe = GnosisSafe(payable(address(gnosisSafeProxy)));

        return address(gnosisSafe);
    }

    function createSafeTxHash(Transaction memory safeTx, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        bytes32 txHashed = gnosisSafe.getTransactionHash(
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

        return txHashed;
    }

    function createDefaultTx(address to, bytes memory data) public pure returns (Transaction memory) {
        bytes memory emptyData;
        Transaction memory defaultTx = Transaction(
                    to,
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
        return defaultTx;
    }
}