// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {KeyperModule} from "../src/KeyperModule.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
// import {IGnosisSafe} from "./GnosisSafeInterfaces.sol";
import {console} from "forge-std/console.sol";

contract Attacker {
    // KeyperModule is the contract to mock the attack
    KeyperModule public keyperModule;
    // IGnosisSafe public gnosisInterface;

    constructor(address _contractToAttackAddress) {
        keyperModule = KeyperModule(_contractToAttackAddress);
        // gnosisInterface = IGnosisSafe(address(this));
    }

    //this is called when Attackee sends Ether to this contract (Attacker)
    receive() external payable {
        //comment this out to allow the withdrawal
        if(address(this).balance >= 1 gwei) {
            keyperModule.execTransactionOnBehalf(
                org, targetSafe, to, value, data, operation, signatures
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
        result = keyperModule.execTransactionOnBehalf(
            org, targetSafe, to, value, data, operation, signatures
        );
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
}
