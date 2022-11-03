// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {Constants} from "../src/Constants.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import "./GnosisSafeHelper.t.sol";

contract KeyperRolesTest is Test, Constants {
    using Address for address;

    GnosisSafeHelper gnosisHelper;
    KeyperRoles keyperRoles;
    address gnosisSafeAddr;
    address keyperModuleDeployed;

    function setUp() public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper module
        keyperModuleDeployed = factory.getDeployed(address(this), salt);
        // Deployment with keyper module address
        keyperRoles = new KeyperRoles(keyperModuleDeployed);

        bytes memory args = abi.encode(
            address(0xBEEF), //Master copy address does not matter
            address(0xCAAF), // Same proxy factory
            address(keyperRoles)
        );

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperModule.sol:KeyperModule"), args);

        factory.deploy(salt, bytecode);

        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv(0);
    }

    function testRolesModulesSetup() public {
        // Check KeyperModule has role capabilites
        assertEq(
            keyperRoles.doesRoleHaveCapability(
                SAFE_LEAD, keyperModuleDeployed, ADD_OWNER
            ),
            true
        );
        assertEq(
            keyperRoles.doesRoleHaveCapability(
                SAFE_LEAD, keyperModuleDeployed, REMOVE_OWNER
            ),
            true
        );
        // Check roleAuthority owner is set to keyper module
        assertEq(keyperRoles.owner(), keyperModuleDeployed);
    }

    function testSetSafeRoleOnOrgRegister() public {
        address org1 = gnosisSafeAddr;
        vm.startPrank(org1);

        KeyperModule keyperModule = KeyperModule(keyperModuleDeployed);
        keyperModule.registerOrg("Org1");
        // Check Role
        assertEq(
            keyperRoles.doesRoleHaveCapability(
                ROOT_SAFE, address(keyperModule), ROLE_ASSIGMENT
            ),
            true
        );
    }
}
