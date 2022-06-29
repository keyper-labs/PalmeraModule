// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../script/DeploySafe.t.sol";

contract TestDeploySafe is Test {
    DeploySafe deploySafe;

    function setUp() public {
        deploySafe = new DeploySafe();
    }

    function testDeploy() public {
        deploySafe.run();

        // address safeProxy = deploySafe.safeProxy.address;
        address gnosisSafe = deploySafe.gnosisSafe.address;

        address[3] memory owners = [address(0x11), address(0x12), address(0x13)];
        bytes memory emptyData;
        bytes memory setupData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            address(0x0)
        );

        (bool success, bytes memory result) = gnosisSafe.delegatecall(setupData);

        address keyperModule = address(0x2);
        // TODO: Try to encode enable module call
    }
}

