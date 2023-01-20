// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/KeyperRoles.sol";
import "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
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
        CREATE3Factory factory =
            CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
        bytes32 salt = keccak256(abi.encode(0xdfff));
        address keyperModulePredicted = factory.getDeployed(msg.sender, salt);

        // Deploy Safe contracts in goerli
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        uint256 maxTreeDepth = 50;

        // Deploy KeyperRoles: KeyperModule is set as owner of KeyperRoles authority
        KeyperRoles keyperRoles = new KeyperRoles(keyperModulePredicted);
        console.log("KeyperRoles deployed at: ", address(keyperRoles));

        bytes memory args = abi.encode(
            address(masterCopy),
            address(proxyFactory),
            address(keyperRoles),
            maxTreeDepth
        );

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperModule.sol:KeyperModule"), args);

        address keyperModuleAddr = factory.deploy(salt, bytecode);
        console.log("KeyperModule deployed at: ", keyperModuleAddr);

        /// Deploy Guard Contract
        KeyperGuard keyperGuard = new KeyperGuard(keyperModuleAddr);
        console.log("KeyperGuard deployed at: ", address(keyperGuard));

        vm.stopBroadcast();
    }
}
