pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "forge-std/console.sol";

import {GnosisSafeProxyFactory} from "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@safe-contracts/proxies/GnosisSafeProxy.sol";
import {SimulateTxAccessor} from "@safe-contracts/accessors/SimulateTxAccessor.sol";
import {DefaultCallbackHandler} from "@safe-contracts/handler/DefaultCallbackHandler.sol";
import {HandlerContext} from "@safe-contracts/handler/HandlerContext.sol";
// import {CompatibilityFallbackHandler} from "@safe-contracts/handler/CompatibilityFallbackHandler.sol";
import {CreateCall} from "@safe-contracts/libraries/CreateCall.sol";
import {MultiSend} from "@safe-contracts/libraries/MultiSend.sol";
import {MultiSendCallOnly} from "@safe-contracts/libraries/MultiSendCallOnly.sol";
import {SignMessageLib} from "@safe-contracts/libraries/SignMessageLib.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract DeploySafe is Script {
    SimulateTxAccessor simulateTxAccessor;
    GnosisSafeProxyFactory proxyFactory;
    DefaultCallbackHandler defaultHandler;
    HandlerContext handlerContext;
    // CompatibilityFallbackHandler comptFallbackHandler;
    CreateCall createCall;
    MultiSend multisend;
    MultiSendCallOnly multisendCallOnly;
    SignMessageLib signMessageLib;
    GnosisSafe gnosisSafeContract;
    GnosisSafeProxy safeProxy;
    address public safeProxyAddress;

    function run() public {
        vm.startBroadcast();

        simulateTxAccessor = new SimulateTxAccessor();
        proxyFactory = new GnosisSafeProxyFactory();
        defaultHandler = new DefaultCallbackHandler();
        // comptFallbackHandler = new CompatibilityFallbackHandler();
        createCall = new CreateCall();
        multisend = new MultiSend();
        multisendCallOnly = new MultiSendCallOnly();
        signMessageLib = new SignMessageLib();
        gnosisSafeContract = new GnosisSafe();

        bytes memory initializer;
        uint256 nonce = uint256(keccak256(initializer));

        safeProxy = proxyFactory.createProxyWithNonce(
            address(gnosisSafeContract),
            initializer,
            nonce
        );
        safeProxyAddress = address(safeProxy);

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

    function getProxyAddress() public view returns (address) {
        return safeProxyAddress;
    }
}
