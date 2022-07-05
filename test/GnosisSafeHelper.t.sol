pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./SignDigestHelper.t.sol";
import "../script/DeploySafe.t.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract GnosisSafeHelper is Test, SigningUtils, SignDigestHelper {
    GnosisSafe public gnosisSafe;
    DeploySafe public deploySafe;
    uint256[] public privateKeyOwners;
    mapping(address => uint256) ownersPK;

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

    function initOnwers() private {
        privateKeyOwners = new uint256[](10);
        for(uint256 i = 0; i< 10; i++) {
            uint256 pk = i;
            // Avoid deriving public key from 0x address
            if (i == 0) {
                pk = 0xaaa;
            }
            address publicKey = vm.addr(pk);
            ownersPK[publicKey] = pk;
            privateKeyOwners[i] = pk;
        }
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

    function enableModuleTx(address safe, address module) public returns (bool){
        // Create enableModule calldata
        bytes memory data = abi.encodeWithSignature(
            "enableModule(address)",
            address(module)
        );

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);

        // Create encoded tx to be signed
        uint256 nonce = gnosisSafe.nonce();
        bytes32 enableModuleSafeTx = createSafeTxHash(mockTx, nonce);

        address[] memory owners = gnosisSafe.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = gnosisSafe.getThreshold();

        // Get pk for the signing threshold 
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for(uint256 i = 0; i< threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(
            privateKeySafeOwners,
            enableModuleSafeTx
        );

        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function executeSafeTx(Transaction memory mockTx, bytes memory signatures) internal returns (bool){
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

        return result;
    }

    function createOrgTx(string memory orgName, address module) public returns (bool){
        // Create enableModule calldata
        bytes memory data = abi.encodeWithSignature(
            "createOrg(string)",
            orgName
        );

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(module, data);

        // Create encoded tx to be signed
        uint256 nonce = gnosisSafe.nonce();
        bytes32 enableModuleSafeTx = createSafeTxHash(mockTx, nonce);

        address[] memory owners = gnosisSafe.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = gnosisSafe.getThreshold();

        // Get pk for the signing threshold 
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for(uint256 i = 0; i< threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(
            privateKeySafeOwners,
            enableModuleSafeTx
        );

        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }
}
