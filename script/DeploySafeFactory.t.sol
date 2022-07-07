pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "forge-std/console.sol";

import {GnosisSafeProxyFactory} from "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@safe-contracts/proxies/GnosisSafeProxy.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract DeploySafeFactory is Script {
    GnosisSafeProxyFactory proxyFactory;
    GnosisSafe gnosisSafeContract;
    GnosisSafeProxy safeProxy;

    function run() public {
        vm.startBroadcast();
        proxyFactory = new GnosisSafeProxyFactory();
        gnosisSafeContract = new GnosisSafe();
        vm.stopBroadcast();
    }

    function newSafeProxy(bytes memory initializer)
        public
        returns (address)
    {
        uint256 nonce = uint256(keccak256(initializer));
        safeProxy = proxyFactory.createProxyWithNonce(
            address(gnosisSafeContract),
            initializer,
            nonce
        );
        return address(safeProxy);
    }
}
