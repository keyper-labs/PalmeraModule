pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "src/KeyperModule.sol";

contract DeployModule is Script{
    function run() public {
        vm.startBroadcast();
        KeyperModule keyperModule = new KeyperModule();
        vm.stopBroadcast();
    }
}