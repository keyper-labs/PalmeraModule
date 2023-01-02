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
import {KeyperModule, IGnosisSafe} from "../../src/KeyperModule.sol";
import {KeyperRoles} from "../../src/KeyperRoles.sol";
import {KeyperGuard} from "../../src/KeyperGuard.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {console} from "forge-std/console.sol";
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

    // Org, Group and subGroup String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string groupA1Name = "GroupA1";
    string groupA2Name = "GroupA2";
    string groupBName = "GroupB";
    string subGroupA1Name = "subGroupA1";
    string subGroupB1Name = "subGroupB1";
    string subSubgroupA1Name = "SubSubGroupA";

    bytes32 orgHash;

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;

    function deployAllContracts(uint256 initOwners) public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
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
            masterCopy,
            safeFactory,
            address(keyperRolesDeployed),
    		maxTreeDepth
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
}
