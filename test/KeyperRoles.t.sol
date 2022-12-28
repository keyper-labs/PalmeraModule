// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import {MockedContract} from "./mocks/MockedContract.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract KeyperRolesTest is Test {
    using Address for address;

    GnosisSafeHelper gnosisHelper;
    KeyperRoles keyperRoles;

    MockedContract masterCopyMocked;
    MockedContract proxyFactoryMocked;

    address gnosisSafeAddr;
    address keyperModuleDeployed;

    function setUp() public {
        masterCopyMocked = new MockedContract();
        proxyFactoryMocked = new MockedContract();
        uint256 maxLevel = 50;

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper module
        keyperModuleDeployed = factory.getDeployed(address(this), salt);
        // Deployment with keyper module address
        keyperRoles = new KeyperRoles(keyperModuleDeployed);

        bytes memory args = abi.encode(
            address(masterCopyMocked), //Master copy address does not matter
            address(proxyFactoryMocked), // Same proxy factory
            address(keyperRoles),
            maxLevel
        );

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperModule.sol:KeyperModule"), args);

        factory.deploy(salt, bytecode);

        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();
    }

    function testRolesModulesSetup() public {
        // Check KeyperModule has role capabilites
        assertEq(
            keyperRoles.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                keyperModuleDeployed,
                Constants.ADD_OWNER
            ),
            true
        );
        assertEq(
            keyperRoles.doesRoleHaveCapability(
                uint8(DataTypes.Role.SAFE_LEAD),
                keyperModuleDeployed,
                Constants.REMOVE_OWNER
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
                uint8(DataTypes.Role.ROOT_SAFE),
                address(keyperModule),
                Constants.ROLE_ASSIGMENT
            ),
            true
        );
    }
}
