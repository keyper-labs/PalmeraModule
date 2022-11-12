// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import "./GnosisSafeHelper.t.sol";
import "./SignersHelper.t.sol";
import {console} from "forge-std/console.sol";

contract Attacker is SignersHelper {

    // KeyperModule is the contract to mock the attack
    KeyperModule public keyperModule;
    GnosisSafeHelper public gnosisHelper;
    
    constructor(address _contractToAttackAddress) {
        keyperModule = KeyperModule(_contractToAttackAddress);
        initOnwers(10);
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
    
    function getOwners() public returns (address[] memory) {
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        return owners;
    }

    function getThreshold() public pure returns (uint256) {
        return uint256(1);
    }
}