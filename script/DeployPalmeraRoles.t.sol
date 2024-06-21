// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import "../src/PalmeraRoles.sol";

/// @title Deploy PalmeraRoles
/// @custom:security-contact general@palmeradao.xyz
contract DeployPalmeraRoles is Script {
    function run() public {
        // Solenv.config();
        address palmeraModuleMock = address(0xBEEF);
        deploy(palmeraModuleMock);
    }

    function deploy(address palmeraModule) internal {
        vm.startBroadcast();
        PalmeraRoles roles = new PalmeraRoles(palmeraModule);
        vm.stopBroadcast();
    }
}
