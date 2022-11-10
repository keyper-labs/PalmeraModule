// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import "./GnosisSafeHelper.t.sol";
import {console} from "forge-std/console.sol";

contract Attacker {

    // KeyperModule is the contract to mock the attack
    KeyperModule public keyperModule;
    GnosisSafeHelper public gnosisHelper;
    
    constructor(address _contractToAttackAddress) {
        keyperModule = KeyperModule(_contractToAttackAddress);
    }
    
    //this is called when Attackee sends Ether to this contract (Attacker)
    receive() external payable {
        //comment this out to allow the withdrawal
        // if(address(keyperModule).balance >= 1 ether) {
        //    keyperModule.withdrawFromAttackee();
        // }
    }

    function performAttack(
        address org,
        address targetSafe,
        address to, // No needed since we want to drain the funds and transfer them to the attacker contract. //TODO: Check if this is necessary
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    ) 
        external 
        returns (bool result) 
    {
        console.log("Caller from attacker Contract: ", msg.sender);
        gnosisHelper.newKeyperSafe(2, 1);
        result = keyperModule.execTransactionOnBehalf(
            org,
            targetSafe,
            to,
            value,
            data,
            operation,
            signatures
        );
        console.log("Caller from attacker sec instance: ", msg.sender);
    }

    function getBalanceFromSafe(address _safe) external view returns (uint) {
        return address(_safe).balance;
    }
    
    function getBalanceFromAttacker() external view returns (uint) {
        return address(this).balance;
    }
}