// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/DeployModuleWithMockedSafe.t.sol";
import "./helpers/DeployHelper.t.sol";

/// @title TestDeploy
/// @custom:security-contact general@palmeradao.xyz
contract TestDeploy is DeployHelper {
    DeployModuleWithMockedSafe deploy;

    function setUp() public {
        deploy = new DeployModuleWithMockedSafe();
    }

    function testDeploy() public {
        // Deplot Libraries
        (
            address constantsAddr,
            address dataTypesAddr,
            address errorsAddr,
            address eventsAddr
        ) = deployLibraries();

        // Deploy Constants Libraries
        console.log("Constants deployed at: ", constantsAddr);
        // Deploy DataTypes Libraries
        console.log("DataTypes deployed at: ", dataTypesAddr);
        // Deploy Errors Libraries
        console.log("Errors deployed at: ", errorsAddr);
        // Deploy Events Libraries
        console.log("Events deployed at: ", eventsAddr);

        deploy.run();
    }
}
