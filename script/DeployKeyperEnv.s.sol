// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "@solenv/Solenv.sol";
import "../src/KeyperRoles.sol";
import "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

/// Deployement of Gnosis Safe contracts, KeyperRoles and KeyperModule
/// @custom:security-contact general@palmeradao.xyz
contract DeployKeyperEnv is Script {
    function run() public {
        vm.startBroadcast();
        // Using CREATE3Factory to be able to predic deployment address for KeyperModule
        // More info https://github.com/lifinance/create3-factory
        // The address https://sepolia.etherscan.io/address/0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1#code, is the address of the CREATE3Factory in Sepolia
        CREATE3Factory factory =
            CREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);
        // Salt is a random number that is used to predict the deployment address
        bytes32 salt = keccak256(abi.encode(0xddff)); // need to be unique to avoid collision
        address keyperModulePredicted = factory.getDeployed(msg.sender, salt);

        // Deploy Safe contracts in any network
        Solenv.config();
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        uint256 maxTreeDepth = 50;

        // Deploy KeyperRoles: KeyperModule is set as owner of KeyperRoles authority
        console.log("KeyperModulePredicted: ", keyperModulePredicted);
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
