// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import "../src/KeyperRoles.sol";

// import "@solenv/Solenv.sol";

contract DeployKeyperRoles is Script {
    function run() public {
        // Solenv.config();
        address keyperModuleMock = address(0xBEEF);
        deploy(keyperModuleMock);
    }

    function deploy(address keyperModule) internal {
        vm.startBroadcast();
        KeyperRoles roles = new KeyperRoles(keyperModule);
        vm.stopBroadcast();
    }
}
