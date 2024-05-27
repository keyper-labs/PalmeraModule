// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/SigningUtils.sol";
import "./SafeHelper.t.sol";
import "./PalmeraModuleHelper.t.sol";
import "./PalmeraSafeBuilder.t.sol";
import {Constants} from "../../libraries/Constants.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import {Errors} from "../../libraries/Errors.sol";
import {Events} from "../../libraries/Events.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";
import {PalmeraRoles} from "../../src/PalmeraRoles.sol";
import {PalmeraGuard} from "../../src/PalmeraGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

/// @title Deploy Helper
/// @custom:security-contact general@palmeradao.xyz
contract DeployHelper is Test {
    using SafeMath for uint256;

    PalmeraModule palmeraModule;
    PalmeraGuard palmeraGuard;
    SafeHelper safeHelper;
    PalmeraModuleHelper palmeraHelper;
    PalmeraRoles palmeraRolesContract;
    PalmeraSafeBuilder palmeraSafeBuilder;

    address safeAddr;
    address palmeraModuleAddr;
    address palmeraGuardAddr;
    address palmeraRolesDeployed;
    address receiver = address(0xABC);
    address zeroAddress = address(0x0);
    address sentinel = address(0x1);

    // Org, Safe and subSafe String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string safeA1Name = "SafeA1";
    string safeA2Name = "SafeA2";
    string safeBName = "SafeB";
    string subSafeA1Name = "subSafeA1";
    string subSafeB1Name = "subSafeB1";
    string subSubSafeA1Name = "SubSubSafeA";

    bytes32 orgHash;

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) palmeraSafes;

    function deployAllContracts(uint256 initOwners) public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        /// get address of deployed libraries
        (
            address constantsAddr,
            address dataTypesAddr,
            address errorsAddr,
            address eventsAddr
        ) = deployLibraries();

        // Predict the future address of palmera roles
        palmeraRolesDeployed = factory.getDeployed(address(this), salt);

        // Init a new safe as main organisation (3 owners, 1 threshold)
        safeHelper = new SafeHelper();
        safeAddr = safeHelper.setupSeveralSafeEnv(initOwners);

        // setting palmeraRoles Address
        safeHelper.setPalmeraRoles(palmeraRolesDeployed);

        // Init PalmeraModule
        uint256 maxTreeDepth = 50;

        palmeraModule =
            new PalmeraModule(address(palmeraRolesDeployed), maxTreeDepth);
        palmeraModuleAddr = address(palmeraModule);
        // Deploy Guard Contract
        palmeraGuard = new PalmeraGuard(payable(palmeraModuleAddr));
        palmeraGuardAddr = address(palmeraGuard);

        // Init palmeraModuleHelper
        palmeraHelper = new PalmeraModuleHelper();
        palmeraHelper.initHelper(palmeraModule, initOwners.div(3));
        // Update safeHelper
        safeHelper.setPalmeraModule(palmeraModuleAddr);
        // Update safeHelper
        safeHelper.setPalmeraGuard(palmeraGuardAddr);
        // Enable palmera module
        safeHelper.enableModuleTx(safeAddr);
        // Enable palmera Guard
        safeHelper.enableGuardTx(safeAddr);

        orgHash = keccak256(abi.encodePacked(orgName));

        bytes memory args = abi.encode(address(palmeraModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("PalmeraRoles.sol:PalmeraRoles"), args);

        palmeraRolesContract =
            PalmeraRoles(payable(factory.deploy(salt, bytecode)));

        palmeraSafeBuilder = new PalmeraSafeBuilder();
        palmeraSafeBuilder.setUpParams(
            PalmeraModule(palmeraModule), SafeHelper(safeHelper)
        );
    }

    function deployLibraries()
        public
        returns (address, address, address, address)
    {
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
