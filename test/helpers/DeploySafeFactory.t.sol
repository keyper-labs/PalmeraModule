// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {SafeProxyFactory} from "@safe-contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@safe-contracts/proxies/SafeProxy.sol";
import {Safe} from "@safe-contracts/Safe.sol";
import {IProxyCreationCallback} from
    "@safe-contracts/proxies/IProxyCreationCallback.sol";

/// @title DeploySafeFactory
/// @custom:security-contact general@palmeradao.xyz
contract DeploySafeFactory is Script {
    SafeProxyFactory public proxyFactory;
    Safe public safeContract;
    SafeProxy safeProxy;

    // Deploys a SafeProxyFactory & Safe contract
    function run() public {
        vm.startBroadcast();
        proxyFactory = new SafeProxyFactory();
        safeContract = new Safe();
        vm.stopBroadcast();
    }

    function newSafeProxy(bytes memory initializer) public returns (address) {
        uint256 nonce = uint256(keccak256(initializer));
        safeProxy = proxyFactory.createProxyWithNonce(
            address(safeContract), initializer, nonce
        );
        return address(safeProxy);
    }
}
