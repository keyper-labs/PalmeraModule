pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {KeyperModuleV2} from "../src/KeyperModuleV2.sol";
import "@solenv/Solenv.sol";

contract DeployKeyperSafe is Script {
    function run() public {
        Solenv.config();
        address keyperModuleAddress = vm.envAddress("KEYPER_MODULE_ADDRESS");
        address[] memory owners = new address[](2);
        owners[0] = vm.envAddress("OWNER_1");
        owners[1] = vm.envAddress("OWNER_2");
        uint256 threshold = vm.envUint("THRESHOLD");

        vm.startBroadcast();
        KeyperModuleV2 keyper = KeyperModuleV2(keyperModuleAddress);
        keyper.createSafeProxy(owners, threshold);
        vm.stopBroadcast();
    }
}
