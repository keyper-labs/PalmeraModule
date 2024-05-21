// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {ISafe, ISafeProxy} from "./SafeInterfaces.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {
    DenyHelper,
    Address,
    Context,
    GnosisSafeMath,
    Constants,
    DataTypes,
    Errors,
    Events
} from "./DenyHelper.sol";
import {SignatureDecoder} from "@safe-contracts/common/SignatureDecoder.sol";

/// @title Helpers
/// @custom:security-contact general@palmeradao.xyz
abstract contract Helpers is DenyHelper, SignatureDecoder {
    using GnosisSafeMath for uint256;
    using Address for address;

    /// @dev Modifier for Validate if the address is a Safe Smart Account Wallet
    /// @param safe Address of the Safe Smart Account Wallet
    modifier IsSafe(address safe) {
        if (
            safe == address(0) || safe == Constants.SENTINEL_ADDRESS
                || !isSafe(safe)
        ) {
            revert Errors.InvalidSafe(safe);
        }
        _;
    }

    /// @dev Method to get the domain separator for Keyper Module
    /// @return Hash of the domain separator
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(Constants.DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this)
        );
    }

    /// @dev Returns the chain id used by this contract.
    /// @return The Chain ID
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    /// @dev Method to get the Encoded Packed Data for Keyper Transaction
    /// @param org Hash(on-chain Organisation)
    /// @param superSafe address of the caller
    /// @param targetSafe address of the Safe
    /// @param to address of the receiver
    /// @param value value of the transaction
    /// @param data data of the transaction
    /// @param operation operation of the transaction
    /// @param _nonce nonce of the transaction
    /// @return Hash of the encoded data
    function encodeTransactionData(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    ) public view returns (bytes memory) {
        bytes32 keyperTxHash = keccak256(
            abi.encode(
                Constants.KEYPER_TX_TYPEHASH,
                org,
                superSafe,
                targetSafe,
                to,
                value,
                keccak256(data),
                operation,
                _nonce
            )
        );
        return abi.encodePacked(
            bytes1(0x19), bytes1(0x01), domainSeparator(), keyperTxHash
        );
    }

    /// @dev Method to get the Hash Encoded Packed Data for Keyper Transaction
    /// @param org Hash(on-chain Organisation)
    /// @param superSafe address of the caller
    /// @param targetSafe address of the Safe
    /// @param to address of the receiver
    /// @param value value of the transaction
    /// @param data data of the transaction
    /// @param operation operation of the transaction
    /// @param _nonce nonce of the transaction
    /// @return Hash of the encoded packed data
    function getTransactionHash(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(
            encodeTransactionData(
                org, superSafe, targetSafe, to, value, data, operation, _nonce
            )
        );
    }

    /// @notice Method to Validate if address is a Safe Smart Account Wallet
    /// @dev This method is used to validate if the address is a Safe Smart Account Wallet
    /// @param safe Address to validate
    /// @return bool
    function isSafe(address safe) public view returns (bool) {
        /// Check if the address is a Safe Smart Account Wallet
        if (safe.isContract()) {
            /// Check if the address is a Safe Smart Account Wallet
            bytes memory payload = abi.encodeWithSignature("getThreshold()");
            (bool success, bytes memory returnData) = safe.staticcall(payload);
            if (!success) return false;
            /// Check if the address is a Safe Smart Account Wallet
            uint256 threshold = abi.decode(returnData, (uint256));
            if (threshold == 0) return false;
            return true;
        } else {
            return false;
        }
    }

    /// @dev Method to get signatures order
    /// @param signatures Signature of the transaction
    /// @param dataHash Hash of the transaction data to sign
    /// @param owners Array of owners of the  Safe Smart Account Wallet
    /// @return address of the Safe Proxy
    function processAndSortSignatures(
        bytes memory signatures,
        bytes32 dataHash,
        address[] memory owners
    ) internal pure returns (bytes memory) {
        uint256 count = signatures.length / 65;
        bytes memory concatenatedSignatures;

        for (uint256 j = 0; j < owners.length; j++) {
            address currentOwner = owners[j];
            for (uint256 i = 0; i < count; i++) {
                // Inline 'signatureSplit' logic here (r, s, v extraction)
                (uint8 v, bytes32 r, bytes32 s) = signatureSplit(signatures, i);

                // Recover signer from the signature
                address signer = ecrecover(dataHash, v, r, s);
                // Combine r, s, v into a signature
                bytes memory signature = abi.encodePacked(r, s, v);

                if (signer == currentOwner) {
                    concatenatedSignatures =
                        abi.encodePacked(concatenatedSignatures, signature);
                    break;
                }
            }
        }
        return concatenatedSignatures;
    }

    /// @dev Method to get Preview Module of the Safe
    /// @param safe address of the Safe
    /// @return address of the Preview Module
    function getPreviewModule(address safe) internal view returns (address) {
        // create Instance of the Safe
        ISafe safeInstance = ISafe(safe);
        // get the modules of the Safe
        (address[] memory modules, address nextModule) =
            safeInstance.getModulesPaginated(address(this), 25);
        if ((modules.length == 0) && (nextModule == Constants.SENTINEL_ADDRESS))
        {
            return Constants.SENTINEL_ADDRESS;
        } else {
            for (uint256 i = 1; i < modules.length; ++i) {
                if (modules[i] == address(this)) {
                    return modules[i - 1];
                }
            }
        }
    }

    /// @dev refactoring of execution of Tx with the privilege of the Module Keyper Labs, and avoid repeat code
    /// @param safe Safe Address to execute Tx
    /// @param data Data to execute Tx
    function _executeModuleTransaction(address safe, bytes memory data)
        internal
    {
        ISafe targetSafe = ISafe(safe);
        bool result = targetSafe.execTransactionFromModule(
            safe, uint256(0), data, Enum.Operation.Call
        );
        if (!result) revert Errors.TxExecutionModuleFailed();
    }
}
