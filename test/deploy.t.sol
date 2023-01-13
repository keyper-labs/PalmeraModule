// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/DeployModule.t.sol";

/// @title TestDeploy
/// @custom:security-contact general@palmeradao.xyz
contract TestDeploy is Test {
    DeployModule deploy;

    function setUp() public {
        deploy = new DeployModule();
    }

    function testDeploy() public {
        deploy.run();
    }
}
