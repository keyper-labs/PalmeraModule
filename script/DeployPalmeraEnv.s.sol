// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "@solenv/Solenv.sol";
import "../src/PalmeraRoles.sol";
import "../src/PalmeraModule.sol";
import {PalmeraGuard} from "../src/PalmeraGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

/// Deployement of Safe contracts, PalmeraRoles and PalmeraModule
/// @custom:security-contact general@palmeradao.xyz
contract DeployPalmeraEnv is Script {
    function run() public {
        vm.startBroadcast();
        // Using CREATE3Factory to be able to predic deployment address for PalmeraModule
        // More info https://github.com/lifinance/create3-factory
        // The address https://sepolia.etherscan.io/address/0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1#code, is the address of the CREATE3Factory in Sepolia
        CREATE3Factory factory =
            CREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);
        // Salt is a random number that is used to predict the deployment address
        bytes32 salt = keccak256(abi.encode(0xddff)); // need to be unique to avoid collision
        address palmeraModulePredicted = factory.getDeployed(msg.sender, salt);

        // Deploy Safe contracts in any network
        Solenv.config();
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        uint256 maxTreeDepth = 50;

        // Deploy PalmeraRoles: PalmeraModule is set as owner of PalmeraRoles authority
        console.log("PalmeraModulePredicted: ", palmeraModulePredicted);
        PalmeraRoles palmeraRoles = new PalmeraRoles(palmeraModulePredicted);
        console.log("PalmeraRoles deployed at: ", address(palmeraRoles));

        bytes memory args = abi.encode(
            address(masterCopy),
            address(proxyFactory),
            address(palmeraRoles),
            maxTreeDepth
        );

        bytes memory bytecode = abi.encodePacked(
            vm.getCode("PalmeraModule.sol:PalmeraModule"), args
        );

        address palmeraModuleAddr = factory.deploy(salt, bytecode);
        console.log("PalmeraModule deployed at: ", palmeraModuleAddr);

        /// Deploy Guard Contract
        PalmeraGuard palmeraGuard = new PalmeraGuard(palmeraModuleAddr);
        console.log("PalmeraGuard deployed at: ", address(palmeraGuard));

        vm.stopBroadcast();
    }
}
