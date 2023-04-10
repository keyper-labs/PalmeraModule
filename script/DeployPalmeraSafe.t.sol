// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {PalmeraModule} from "../src/PalmeraModule.sol";
import "@solenv/Solenv.sol";

contract DeployPalmeraSafe is Script {
    function run() public {
        Solenv.config();
        address keyperModuleAddress = vm.envAddress("PALMERA_MODULE_ADDRESS");
        address[] memory owners = new address[](2);
        owners[0] = vm.envAddress("OWNER_1");
        owners[1] = vm.envAddress("OWNER_2");
        uint256 threshold = vm.envUint("THRESHOLD");

        vm.startBroadcast();
        PalmeraModule keyper = PalmeraModule(keyperModuleAddress);
        keyper.createSafeProxy(owners, threshold);
        vm.stopBroadcast();
    }
}
