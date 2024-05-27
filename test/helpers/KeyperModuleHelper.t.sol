// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {DeploySafeFactory} from "../../script/DeploySafeFactory.t.sol";

/// @notice Helper contract handling KeyperModule
/// @custom:security-contact general@palmeradao.xyz
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
    GnosisSafe public safeHelper;

    /// function to initialize the helper
    /// @param _keyper instance of KeyperModule
    /// @param numberOwners number of owners to initialize
    function initHelper(KeyperModule _keyper, uint256 numberOwners) public {
        keyper = _keyper;
        initOnwers(numberOwners);
    }

    /// fucntion to set the Safe instance
    /// @param safe address of the Safe instance
    function setSafe(address safe) public {
        safeHelper = GnosisSafe(payable(safe));
    }

    /// function Encode signatures for a keypertx
    /// @param org Organisation address
    /// @param superSafe Super Safe address
    /// @param targetSafe Target Safe address
    /// @param to Address to send the transaction
    /// @param value Value to send
    /// @param data Data payload
    /// @param operation Operation type
    /// @return signatures Packed signatures data (v, r, s)
    function encodeSignaturesKeyperTx(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        // Create encoded tx to be signed
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org, superSafe, targetSafe, to, value, data, operation, nonce
        );

        address[] memory owners = safeHelper.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = safeHelper.getThreshold();

        // Get pk for the signing threshold
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(privateKeySafeOwners, txHashed);

        return signatures;
    }

    /// function Sign keyperTx with invalid signatures (do not belong to any safe owner)
    /// @param org Organisation address
    /// @param superSafe Super Safe address
    /// @param targetSafe Target Safe address
    /// @param to Address to send the transaction
    /// @param value Value to send
    /// @param data Data payload
    /// @param operation Operation type
    /// @return signatures Packed signatures data (v, r, s)
    function encodeInvalidSignaturesKeyperTx(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        // Create encoded tx to be signed
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org, superSafe, targetSafe, to, value, data, operation, nonce
        );

        uint256 threshold = safeHelper.getThreshold();
        // Get invalid pk for the signing threshold
        uint256[] memory invalidSafeOwnersPK = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            invalidSafeOwnersPK[i] = invalidPrivateKeyOwners[i];
        }

        bytes memory signatures = signDigestTx(invalidSafeOwnersPK, txHashed);

        return signatures;
    }

    /// function to create a keyperTx hash
    /// @param org Organisation address
    /// @param superSafe Super Safe address
    /// @param targetSafe Target Safe address
    /// @param to Address to send the transaction
    /// @param value Value to send
    /// @param data Data payload
    /// @param operation Operation type
    /// @param nonce Nonce of the transaction
    /// @return txHashed Hash of the transaction
    function createKeyperTxHash(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 txHashed = keyper.getTransactionHash(
            org, superSafe, targetSafe, to, value, data, operation, nonce
        );
        return txHashed;
    }
}
