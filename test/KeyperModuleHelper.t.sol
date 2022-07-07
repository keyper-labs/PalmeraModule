pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract KeyperModuleHelper is Test, SignDigestHelper, SignersHelper {
    struct KeyperTransaction {
        address org;
        address safe;
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
    }

    KeyperModule keyper;
    GnosisSafe public gnosisSafe;

    function initHelper(KeyperModule _keyper, uint256 numberOwners) public {
        keyper = _keyper;
        initOnwers(numberOwners);
    }

    function setGnosisSafe(address safe) public {
        gnosisSafe = GnosisSafe(payable(safe));
    }

    function encodeSignaturesKeyperTx(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public returns (bytes memory) {
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

        bytes memory signatures = signDigestTx(privateKeySafeOwners, txHashed);

        return signatures;
    }

    function encodeInvalidSignaturesKeyperTx(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public returns (bytes memory) {
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

        uint256 threshold = gnosisSafe.getThreshold();
        // Get invalid pk for the signing threshold
        uint256[] memory invalidSafeOwnersPK = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            invalidSafeOwnersPK[i] = invalidPrivateKeyOwners[i];
        }

        bytes memory signatures = signDigestTx(invalidSafeOwnersPK, txHashed);

        return signatures;
    }

    function createKeyperTxHash(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) public view returns (bytes32) {
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
}
