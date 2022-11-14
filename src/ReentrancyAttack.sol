// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {console} from "forge-std/console.sol";

contract Attacker {

    // KeyperModule is the contract to mock the attack
    KeyperModule public keyperModule;
    
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
        result = keyperModule.execTransactionOnBehalf(
            org,
            targetSafe,
            to,
            value,
            data,
            operation,
            signatures
        );
    }

    function getBalanceFromSafe(address _safe) external view returns (uint) {
        return address(_safe).balance;
    }
    
    function getBalanceFromAttacker() external view returns (uint) {
        return address(this).balance;
    }
    
    function getOwners() public pure returns (address[] memory) {
        address[] memory owners = new address[](3);
        // ! The owners MUST NOT vm mocked addresses
        owners[0] = address(0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69);
        owners[1] = address(0xe1AB8145F7E55DC933d51a18c793F901A3A0b276);
        owners[2] = address(0xd41c057fd1c78805AAC12B0A94a405c0461A6FBb);
        return owners;
    }

    function getThreshold() public pure returns (uint256) {
        uint256 ownersLength = getOwners().length;
        return uint256(ownersLength);
    }
}