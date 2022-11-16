pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Attacker} from "../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {DeploySafeFactory} from "../script/DeploySafeFactory.t.sol";

contract KeyperModuleHelper is Test, SignDigestHelper, SignersHelper {
    struct KeyperTransaction {
        address org;
        address safe;
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
    }

    KeyperModule public keyper;
    GnosisSafe public gnosisSafe;
    Attacker public attacker;

    function initHelper(KeyperModule _keyper, Attacker _attacker, uint256 numberOwners) public {
        keyper = _keyper;
        attacker = _attacker;
        initOnwers(numberOwners);
    }

    function setGnosisSafe(address safe) public {
        gnosisSafe = GnosisSafe(payable(safe));
    }

    /// @notice Encode signatures for a keypertx
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
            org, safe, to, value, data, operation, nonce
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

    /// @notice Sign keyperTx with invalid signatures (do not belong to any safe owner)
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
            org, safe, to, value, data, operation, nonce
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

    function encodeSignaturesForAttackKeyperTx(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public returns (bytes memory) {
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org, safe, to, value, data, operation, nonce
        );

        uint256 threshold = attacker.getThreshold();
        address[] memory owners = attacker.getOwners();
        address[] memory sortedOwners = sortAddresses(owners);

        uint256[] memory ownersPKFromAttacker = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            ownersPKFromAttacker[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(ownersPKFromAttacker, txHashed);

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
            org, safe, to, value, data, operation, nonce
        );
        return txHashed;
    }

    function createSafeProxy(uint256 numberOwners, uint256 threshold)
        public
        returns (address)
    {
        require(
            privateKeyOwners.length >= numberOwners,
            "not enough initialized owners"
        );
        require(
            countUsed + numberOwners <= privateKeyOwners.length,
            "No private keys available"
        );
        DeploySafeFactory deploySafeFactory = new DeploySafeFactory();
        deploySafeFactory.run();

        address masterCopy = address(deploySafeFactory.gnosisSafeContract());
        address safeFactory = address(deploySafeFactory.proxyFactory());
        address rolesAuthority = address(deploySafeFactory.proxyFactory());
        keyper = new KeyperModule(masterCopy, safeFactory, rolesAuthority);

        require(address(keyper) != address(0), "Keyper module not deployed");
        address[] memory owners = new address[](numberOwners);
        for (uint256 i = 0; i < numberOwners; i++) {
            owners[i] = vm.addr(privateKeyOwners[i + countUsed]);
            countUsed++;
        }
        return keyper.createSafeProxy(owners, threshold);
    }
}
