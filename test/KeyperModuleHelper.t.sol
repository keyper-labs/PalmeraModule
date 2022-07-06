pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract KeyperModuleHelper is Test, SignDigestHelper {
    KeyperModule keyper;
    GnosisSafe public gnosisSafe;
    uint256[] public privateKeyOwners;
    mapping(address => uint256) ownersPK;

    struct KeyperTransaction {
        address org;
        address safe;
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
    }

    // TODO find a way to share this owners between helpers
    function initOnwers(uint256 numberOwners) private {
        privateKeyOwners = new uint256[](numberOwners);
        for (uint256 i = 0; i < numberOwners; i++) {
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

    function initHelper(KeyperModule _keyper, uint256 numberOwners) public {
        keyper = _keyper;
        initOnwers(numberOwners);
    }

    function setGnosisSafe(address safe) public {
        gnosisSafe = GnosisSafe(payable(safe));
    }

    function createKeyperTxHash(address org, address safe, address to, uint256 value, bytes memory data, Enum.Operation operation, uint256 nonce) public view returns (bytes32){
        bytes32 txHashed = keyper.getTransactionHash(
                    org,
                    safe,
                    to,
                    value,
                    data,
                    operation,
                    nonce
                );
        return txHashed;
    }

    // function createExecTransactionOnBehalfTx(
    //     address org,
    //     address safe,
    //     address to,
    //     uint256 value,
    //     bytes calldata data,
    //     Enum.Operation operation,
    //     bytes memory signatures
    // ) public returns (bool) {
    //     bytes memory data = abi.encodeWithSignature(
    //         "execTransactionOnBehalf(address,address,address,uint256,bytes,uint8)",
    //         org,
    //         safe,
    //         to,
    //         value,
    //         data,
    //         operation,
    //     );
    //     // Sign tx
    //     bytes memory signatures = encodeSignaturesModuleSafeTx(org, safe, to, value, data, operation);
    //     bool result = executeSafeTx(mockTx, signatures);
    //     return true;
    // }

    function encodeSignaturesKeyperTx(address org, address safe, address to, uint256 value, bytes memory data, Enum.Operation operation)
        public
        returns (bytes memory)
    {
        // Create encoded tx to be signed
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org,
            safe,
            to,
            value,
            data,
            operation,
            nonce
        );

        address[] memory owners = gnosisSafe.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = gnosisSafe.getThreshold();

        // Get pk for the signing threshold
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(
            privateKeySafeOwners,
            txHashed
        );

        return signatures;
    }
}