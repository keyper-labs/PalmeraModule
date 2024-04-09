// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@safe-contracts/proxies/GnosisSafeProxy.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {IProxyCreationCallback} from
    "@safe-contracts/proxies/IProxyCreationCallback.sol";
import "@solenv/Solenv.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Random} from "../libraries/Random.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "../src/Helpers.sol";

/// @title DeploySafeFactory
/// @custom:security-contact general@palmeradao.xyz
contract DeploySafe is Script {
    IGnosisSafe public gnosisSafe;
    address masterCopy;
    uint256 threshold;
    address proxyFactory;
    address[] owners;

    // Deploys a GnosisSafeProxyFactory & GnosisSafe contract
    function run() public {
        vm.startBroadcast();
        //     proxyFactory = new GnosisSafeProxyFactory();
        //     gnosisSafeContract = new GnosisSafe();
        Solenv.config();
        masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        console.logAddress(masterCopy);
        proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        console.logAddress(proxyFactory);
        owners = new address[](2);
        owners[0] = vm.envAddress("OWNER_1");
        owners[1] = vm.envAddress("OWNER_2");
        console.log("Owners %s, %s: ", owners[0], owners[1]);
        threshold = vm.envUint("THRESHOLD");
        console.logUint(threshold);
        createSafeProxy();
        vm.stopBroadcast();
    }

    function newSafeProxy(bytes memory initializer)
        public
        returns (address newProxyAddress)
    {
        uint256 nonce = Random.rand((uint256(keccak256(initializer))));
        IGnosisSafeProxy safeProxy = IGnosisSafeProxy(proxyFactory);
        newProxyAddress = safeProxy.createProxyWithNonce(
            address(masterCopy), initializer, nonce
        );
    }

    /// @dev Function to create Gnosis Safe Multisig Wallet with our module enabled
    /// @return safe Address of Safe created with the module enabled
    function createSafeProxy() public returns (address safe) {
        bytes memory data = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0x0),
            "0x",
            address(0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99), // Fallback Handler
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );
        console.logBytes(data);
        address newSafe = newSafeProxy(data);
        gnosisSafe = IGnosisSafe(payable(newSafe));
        console.logAddress(newSafe);
    }
}
