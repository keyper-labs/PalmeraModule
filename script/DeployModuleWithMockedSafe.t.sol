// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "src/PalmeraModule.sol";
import "test/mocks/MockedContract.t.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import "@solenv/Solenv.sol";

/// Deployement of Safe contracts, PalmeraRoles and PalmeraModule
/// @custom:security-contact general@palmeradao.xyz
contract DeployModuleWithMockedSafe is Script {
    function run() public {
        Solenv.config();
        address rolesAuthority = address(0xBEEF);
        uint256 maxTreeDepth = 50;
        vm.startBroadcast();
        PalmeraModule palmeraModule =
            new PalmeraModule(rolesAuthority, maxTreeDepth);
        vm.stopBroadcast();
    }
}
