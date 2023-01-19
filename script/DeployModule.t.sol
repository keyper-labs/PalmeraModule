// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "src/KeyperModule.sol";
import "test/mocks/MockedContract.t.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import "@solenv/Solenv.sol";

contract DeployModule is Script {
    function run() public {
        Solenv.config();
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        vm.startBroadcast();
        MockedContract masterCopyMocked = new MockedContract();
        MockedContract proxyFactoryMocked = new MockedContract();
        KeyperModule keyperModule = new KeyperModule(
            address(masterCopyMocked),
            address(proxyFactoryMocked),
            rolesAuthority,
            maxTreeDepth
        );
        vm.stopBroadcast();
    }
}
