// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import "./KeyperSafeBuilder.t.sol";
import {Constants} from "../../libraries/Constants.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import {Errors} from "../../libraries/Errors.sol";
import {Events} from "../../libraries/Events.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {KeyperRoles} from "../../src/KeyperRoles.sol";
import {KeyperGuard} from "../../src/KeyperGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

contract DeployHelper is Test {
    using SafeMath for uint256;

    KeyperModule keyperModule;
    KeyperGuard keyperGuard;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;
    KeyperSafeBuilder keyperSafeBuilder;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperGuardAddr;
    address keyperRolesDeployed;
    address receiver = address(0xABC);
    address zeroAddress = address(0x0);
    address sentinel = address(0x1);

    // Org, Squad and subSquad String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string squadA1Name = "SquadA1";
    string squadA2Name = "SquadA2";
    string squadBName = "SquadB";
    string subSquadA1Name = "subSquadA1";
    string subSquadB1Name = "subSquadB1";
    string subSubSquadA1Name = "SubSubSquadA";

    bytes32 orgHash;

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;

    function deployAllContracts(uint256 initOwners) public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));

        (
            address constantsAddr,
            address dataTypesAddr,
            address errorsAddr,
            address eventsAddr
        ) = deployLibraries();

        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSeveralSafeEnv(initOwners);

        // setting keyperRoles Address
        gnosisHelper.setKeyperRoles(keyperRolesDeployed);

        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        uint256 maxTreeDepth = 50;

        keyperModule = new KeyperModule(
            masterCopy, safeFactory, address(keyperRolesDeployed), maxTreeDepth
        );
        keyperModuleAddr = address(keyperModule);
        // Deploy Guard Contract
        keyperGuard = new KeyperGuard(keyperModuleAddr);
        keyperGuardAddr = address(keyperGuard);

        // Init keyperModuleHelper
        keyperHelper = new KeyperModuleHelper();
        keyperHelper.initHelper(keyperModule, initOwners.div(3));
        // Update gnosisHelper
        gnosisHelper.setKeyperModule(keyperModuleAddr);
        // Update gnosisHelper
        gnosisHelper.setKeyperGuard(keyperGuardAddr);
        // Enable keyper module
        gnosisHelper.enableModuleTx(gnosisSafeAddr);
        // Enable keyper Guard
        gnosisHelper.enableGuardTx(gnosisSafeAddr);

        orgHash = keccak256(abi.encodePacked(orgName));

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        keyperRolesContract = KeyperRoles(factory.deploy(salt, bytecode));

        keyperSafeBuilder = new KeyperSafeBuilder();
        // keyperSafeBuilder.setGnosisHelper(GnosisSafeHelper(gnosisHelper));
        keyperSafeBuilder.setUpParams(
            KeyperModule(keyperModule), GnosisSafeHelper(gnosisHelper)
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
