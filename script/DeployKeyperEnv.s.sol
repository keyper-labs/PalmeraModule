// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/KeyperRoles.sol";
import "../src/KeyperModule.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

// Deployement of Gnosis Safe contracts, KeyperRoles and KeyperModule
contract DeployKeyperEnv is Script {
    function run() public {
        vm.startBroadcast();
        // Using CREATE3Factory to be able to predic deployment address for KeyperModule
        // More info https://github.com/ZeframLou/create3-factory
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        address keyperModulePredicted = factory.getDeployed(msg.sender, salt);

        // Deploy Safe contracts
        GnosisSafeProxyFactory proxyFactory = new GnosisSafeProxyFactory();
        GnosisSafe gnosisSafeContract = new GnosisSafe();

        // Deploy KeyperRoles: KeyperModule is set as owner of KeyperRoles authority
        KeyperRoles keyperRoles = new KeyperRoles(keyperModulePredicted);

        bytes memory args = abi.encode(
            address(gnosisSafeContract),
            address(proxyFactory),
            address(keyperRoles)
        );

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperModule.sol:KeyperModule"), args);

        factory.deploy(salt, bytecode);

        vm.stopBroadcast();
    }
}
