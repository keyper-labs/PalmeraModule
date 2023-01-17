// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/DeployModule.t.sol";
import "./helpers/DeployHelper.t.sol";

/// @title TestDeploy
/// @custom:security-contact general@palmeradao.xyz
contract TestDeploy is Test {
    DeployModule deploy;

    function setUp() public {
        deploy = new DeployModule();
    }

    function testDeploy() public {
        // Deplot Libraries
        (
            address constantsAddr,
            address dataTypesAddr,
            address errorsAddr,
            address eventsAddr
        ) = libraries();

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

    function libraries() public returns (address, address, address, address) {
        // Deploy Constants Libraries
        address constantsAddr =
            address(0x2e234DAe75C793f67A35089C9d99245E1C58470b);
        bytes memory bytecode =
            abi.encodePacked(vm.getCode("Constants.sol:Constants"), "");
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        // Set the bytecode of an arbitrary address
        vm.etch(constantsAddr, deployed.code);
        // Deploy DataTypes Libraries
        address dataTypesAddr =
            address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a);
        bytecode = abi.encodePacked(vm.getCode("DataTypes.sol:DataTypes"), "");
        deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        // Set the bytecode of an arbitrary address
        vm.etch(dataTypesAddr, deployed.code);
        // Deploy Errors Libraries
        address errorsAddr = address(0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9);
        bytecode = abi.encodePacked(vm.getCode("Errors.sol:Errors"), "");
        deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        // Set the bytecode of an arbitrary address
        vm.etch(errorsAddr, deployed.code);
        // Deploy Events Libraries
        address eventsAddr = address(0xc7183455a4C133Ae270771860664b6B7ec320bB1);
        bytecode = abi.encodePacked(vm.getCode("Events.sol:Events"), "");
        deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        // Set the bytecode of an arbitrary address
        vm.etch(eventsAddr, deployed.code);

        return (constantsAddr, dataTypesAddr, errorsAddr, eventsAddr);
    }
}
