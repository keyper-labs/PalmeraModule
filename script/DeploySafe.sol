pragma solidity 0.8.0;
import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {GnosisSafeProxyFactory} from "../../safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {SimulateTxAccessor} from "../../safe-contracts/contracts/accessors/SimulateTxAccessor.sol";
import {DefaultCallbackHandler} from "../../safe-contracts/contracts/handler/DefaultCallbackHandler.sol";
import {HandlerContext} from "../../safe-contracts/contracts/handler/HandlerContext.sol";
import {CompatibilityFallbackHandler} from "../../safe-contracts/contracts/handler/CompatibilityFallbackHandler.sol";
import {CreateCall} from "../../safe-contracts/contracts/libraries/CreateCall.sol";
import {MultiSend} from "../../safe-contracts/contracts/libraries/MultiSend.sol";
import {MultiSendCallOnly} from "../../safe-contracts/contracts/libraries/MultiSendCallOnly.sol";
import {SignMessageLib} from "../../safe-contracts/contracts/libraries/SignMessageLib.sol";
import {GnosisSafe} from "../../safe-contracts/contracts/GnosisSafe.sol";

contract DeploySafe is Test {
    SimulateTxAccessor simulateTxAccessor;
    GnosisSafeProxyFactory proxyFactory;
    DefaultCallbackHandler defaultHandler;
    HandlerContext handlerContext;
    CompatibilityFallbackHandler comptFallbackHandler;
    CreateCall createCall;
    MultiSend multisend;
    MultiSendCallOnly multisendCallOnly;
    SignMessageLib signMessageLib;
    GnosisSafe gnosisSafe;

    function run() public {
        vm.startBroadcast();

        simulateTxAccessor = new SimulateTxAccessor();
        proxyFactory = new GnosisSafeProxyFactory();
        defaultHandler = new DefaultCallbackHandler();
        comptFallbackHandler = new CompatibilityFallbackHandler();
        createCall = new CreateCall();
        multisend = new MultiSend();
        multisendCallOnly = new MultiSendCallOnly();
        signMessageLib = new SignMessageLib();
        gnosisSafe = new GnosisSafe();
        // console.log(gnosisSafe);
        address signer1 = address(0x11);
        address signer2 = address(0x12);
        address signer3 = address(0x13);

        address[3] memory owners = [signer1, signer2, signer3];

        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            uint256(1),
            address(0x0),
            0x0,
            address(comptFallbackHandler),
            0x0,
            uint256(0),
            0x0
        );

        uint256 nonce = uint256(keccak256(initializer));

        proxyFactory.createProxyWithNonce(address(gnosisSafe), initializer, nonce);
        
        vm.stopBroadcast();
    }
}
