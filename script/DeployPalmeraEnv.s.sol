// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/PalmeraRoles.sol";
import "../src/PalmeraModule.sol";
import {PalmeraGuard} from "../src/PalmeraGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

// Deployement of Gnosis Safe contracts, PalmeraRoles and PalmeraModule
contract DeployPalmeraEnv is Script {
    function run() public {
        vm.startBroadcast();
        // Using CREATE3Factory to be able to predic deployment address for PalmeraModule
        // More info https://github.com/ZeframLou/create3-factory
        // The address https://goerli.etherscan.io/address/0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf#code, is the address of the CREATE3Factory in Goerli
        CREATE3Factory factory =
            CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
        bytes32 salt = keccak256(abi.encode(0xdfff));
        address keyperModulePredicted = factory.getDeployed(msg.sender, salt);

        // Deploy Safe contracts in goerli
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        uint256 maxTreeDepth = 50;

        // Deploy PalmeraRoles: PalmeraModule is set as owner of PalmeraRoles authority
        PalmeraRoles keyperRoles = new PalmeraRoles(keyperModulePredicted);
        console.log("PalmeraRoles deployed at: ", address(keyperRoles));

        bytes memory args = abi.encode(
            address(masterCopy),
            address(proxyFactory),
            address(keyperRoles),
            maxTreeDepth
        );

        bytes memory bytecode = abi.encodePacked(
            vm.getCode("PalmeraModule.sol:PalmeraModule"), args
        );

        address keyperModuleAddr = factory.deploy(salt, bytecode);
        console.log("PalmeraModule deployed at: ", keyperModuleAddr);

        /// Deploy Guard Contract
        PalmeraGuard keyperGuard = new PalmeraGuard(keyperModuleAddr);
        console.log("PalmeraGuard deployed at: ", address(keyperGuard));

        vm.stopBroadcast();
    }
}
