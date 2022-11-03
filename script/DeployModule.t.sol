pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "src/KeyperModule.sol";
import "test/MockedContract.t.sol";
import "@solenv/Solenv.sol";

contract DeployModule is Script {
    function run() public {
        Solenv.config();
        address masterCopy = vm.envAddress("MASTER_COPY_ADDRESS");
        address proxyFactory = vm.envAddress("PROXY_FACTORY_ADDRESS");
        address rolesAuthority = address(0xBEEF);
        vm.startBroadcast();
        MockedContractA mockedContractA = new MockedContractA();
        MockedContractB mockedContractB = new MockedContractB();
        KeyperModule keyperModule = new KeyperModule(
            address(mockedContractA),
            address(mockedContractB),
            rolesAuthority
        );
        vm.stopBroadcast();
    }
}
