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
}