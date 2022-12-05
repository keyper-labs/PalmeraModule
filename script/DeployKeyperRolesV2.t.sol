// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import "src/KeyperRolesV2.sol";

// import "@solenv/Solenv.sol";

contract DeployKeyperRoles is Script {
    function run() public {
        // Solenv.config();
        address keyperModuleMock = address(0xBEEF);
        deploy(keyperModuleMock);
    }

    function deploy(address keyperModule) internal {
        vm.startBroadcast();
        KeyperRolesV2 roles = new KeyperRolesV2(keyperModule);
        vm.stopBroadcast();
    }
}
