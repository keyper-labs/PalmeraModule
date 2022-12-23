// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import "./helpers/KeyperModuleHelper.t.sol";
import "./helpers/ReentrancyAttackHelper.t.sol";
import "./helpers/KeyperSafeBuilder.t.sol";
import "./helpers/DeployHelper.t.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {Attacker} from "../src/ReentrancyAttack.sol";
import {console} from "forge-std/console.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

contract StressTestStorage is Test, SigningUtils {
    using SafeMath for uint256;

    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;
    KeyperSafeBuilder keyperSafeBuilder;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    address receiver = address(0xABC);
    address zeroAddress = address(0x0);
    address sentinel = address(0x1);

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;
    string orgName = "Main Org";
    string root2Name = "Second Root";
    string groupA1Name = "GroupA1";
    string groupBName = "GroupB";

    function setUp() public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSpecialSafeEnv();

        // setting keyperRoles Address
        gnosisHelper.setKeyperRoles(keyperRolesDeployed);

        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());

        keyperModule = new KeyperModule(
            masterCopy,
            safeFactory,
            address(keyperRolesDeployed)
        );
        keyperModuleAddr = address(keyperModule);
        // Init keyperModuleHelper
        keyperHelper = new KeyperModuleHelper();
        keyperHelper.initHelper(keyperModule, 30);
        // Update gnosisHelper
        gnosisHelper.setKeyperModule(keyperModuleAddr);
        // Enable keyper module
        gnosisHelper.enableModuleTx(gnosisSafeAddr);

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

    // ! ********************* Stress Test Storage ***********************

    // Initial Test for verification of Add subGroup
    function testAddSubGroup() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        address groupBaddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(groupBaddr);
        uint256 groupIdB = keyperModule.addGroup(groupIdA1, groupBName);
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), true);
        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), true);
        assertEq(keyperModule.isTreeMember(groupIdA1, groupIdB), true);
        assertEq(keyperModule.isSuperSafe(groupIdA1, groupIdB), true);
        vm.stopPrank();
    }

    // Stress Test for Verification of maximal level when add sub Group, in a lineal secuencial way
    function testAddSubGroupLinealSecuenceMaxLevel() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        // Array of Address for the subGroups
        address[] memory subGroupAaddr = new address[](8100);
        uint256[] memory subGroupAid = new uint256[](8100);

        // Assig the Address to first two subGroups
        subGroupAaddr[0] = keyperModule.getGroupSafeAddress(rootId);
        subGroupAaddr[1] = keyperModule.getGroupSafeAddress(groupIdA1);

        // Assig the Id to first two subGroups
        subGroupAid[0] = rootId;
        subGroupAid[1] = groupIdA1;

        for (uint256 i = 2; i < 8100; i++) {
            // Create a new Safe
            subGroupAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Start Prank
            vm.startPrank(subGroupAaddr[i]);
            // Add the new Safe as a subGroup
            try keyperModule.addGroup(subGroupAid[i - 1], groupBName) returns (
                uint256 groupId
            ) {
                subGroupAid[i] = groupId;
                // Stop Prank
                vm.stopPrank();
            } catch Error(string memory reason) {
                console.log("Error: ", reason);
            }

            // Verify that the new Safe is a member of the previous Safe
            assertEq(
                keyperModule.isTreeMember(subGroupAid[i - 1], subGroupAid[i]),
                true
            );
            // Verify that the new Safe is a superSafe of the previous Safe
            assertEq(
                keyperModule.isSuperSafe(subGroupAid[i - 1], subGroupAid[i]),
                true
            );
            // Verify that the new Safe is a member of the root Safe
            assertEq(keyperModule.isTreeMember(rootId, subGroupAid[i]), true);
            // Show in consola the level of the new Safe
            console.log("Level: ", i);
        }
    }

    // Stress Test for Verification of maximal level when add three sub Group, in a lineal secuencial way
    // Struct of Org
    //               Root
    //          /     |     \
    // 	   	   A1     A2    A3
    // 	      /|\     /|\   /|\
    // 	     B1B2B3  B1B2B3 B1B2B3 .....
    function testAddThreeSubGroupLinealSecuenceMaxLevel() public {
        (uint256 rootId, uint256 groupIdA1, uint256 groupIdA2) =
        keyperSafeBuilder.setupRootWithTwoGroups(
            orgName, groupA1Name, groupBName
        );

        // Array of Address for the subGroups
        address[] memory subGroupAaddr = new address[](90000);
        uint256[] memory subGroupAid = new uint256[](90000);
        uint256[] memory level = new uint256[](30000);
        uint256 indexLevel;
        uint256 indexGroup;

        // Assig the Address to first two subGroups
        subGroupAaddr[0] = keyperModule.getGroupSafeAddress(rootId);
        subGroupAaddr[1] = keyperModule.getGroupSafeAddress(groupIdA1);
        subGroupAaddr[2] = keyperModule.getGroupSafeAddress(groupIdA2);
        subGroupAaddr[3] = gnosisHelper.newKeyperSafe(3, 1);

        // Assig the Id to first two subGroups
        subGroupAid[0] = rootId;
        subGroupAid[1] = groupIdA1;
        subGroupAid[2] = groupIdA2;
        // Create group through safe tx
        gnosisHelper.createAddGroupTx(rootId, "GroupA2");
        bytes32 orgHash = keyperModule.getOrgHashBySafe(subGroupAaddr[0]);
        subGroupAid[3] =
            keyperModule.getGroupIdBySafe(orgHash, subGroupAaddr[3]);

        // Assign first level
        level[indexLevel] = 1;
        indexGroup = 4;
        uint256 structLevel = 1;
        for (uint256 i = 1; i < 10000; i++) {
            for (uint256 j = 0; j < 2; j++) {
                // SuperSafe of Iteration
                uint256 superSafe = subGroupAid[level[i] + j];
                // Create a new Safe
                subGroupAaddr[indexGroup] = gnosisHelper.newKeyperSafe(3, 1);
                // Start Prank
                vm.startPrank(subGroupAaddr[indexGroup]);
                // Add the new Safe as a subGroup
                try keyperModule.addGroup(superSafe, groupBName) returns (
                    uint256 groupId
                ) {
                    subGroupAid[indexGroup] = groupId;
                    // Stop Prank
                    vm.stopPrank();
                } catch Error(string memory reason) {
                    console.log("Error: ", reason);
                }

                // Verify that the new Safe is a member of the previous Safe
                assertEq(
                    keyperModule.isTreeMember(
                        superSafe, subGroupAid[indexGroup]
                    ),
                    true
                );
                // Verify that the new Safe is a superSafe of the previous Safe
                assertEq(
                    keyperModule.isSuperSafe(superSafe, subGroupAid[indexGroup]),
                    true
                );
                // Verify that the new Safe is a member of the root Safe
                assertEq(
                    keyperModule.isTreeMember(rootId, subGroupAid[indexGroup]),
                    true
                );
                // Assign next level
                indexLevel++;
                level[indexLevel] = indexGroup;
                // Increment indexGroup
                indexGroup++;
                // Create a new Safe
                subGroupAaddr[indexGroup] = gnosisHelper.newKeyperSafe(3, 1);
                // Start Prank
                vm.startPrank(subGroupAaddr[indexGroup]);
                // Add the new Safe as a subGroup
                try keyperModule.addGroup(superSafe, groupBName) returns (
                    uint256 groupId
                ) {
                    subGroupAid[indexGroup] = groupId;
                    // Stop Prank
                    vm.stopPrank();
                } catch Error(string memory reason) {
                    console.log("Error: ", reason);
                }
                // Verify that the new Safe is a member of the previous Safe
                assertEq(
                    keyperModule.isTreeMember(
                        superSafe, subGroupAid[indexGroup]
                    ),
                    true
                );
                // Verify that the new Safe is a superSafe of the previous Safe
                assertEq(
                    keyperModule.isSuperSafe(superSafe, subGroupAid[indexGroup]),
                    true
                );
                // Verify that the new Safe is a member of the root Safe
                assertEq(
                    keyperModule.isTreeMember(rootId, subGroupAid[indexGroup]),
                    true
                );

                // Increment indexGroup
                indexGroup++;
                // Create a new Safe
                subGroupAaddr[indexGroup] = gnosisHelper.newKeyperSafe(3, 1);
                // Start Prank
                vm.startPrank(subGroupAaddr[indexGroup]);
                // Add the new Safe as a subGroup
                try keyperModule.addGroup(superSafe, groupBName) returns (
                    uint256 groupId
                ) {
                    subGroupAid[indexGroup] = groupId;
                    // Stop Prank
                    vm.stopPrank();
                } catch Error(string memory reason) {
                    console.log("Error: ", reason);
                }
                // Verify that the new Safe is a member of the previous Safe
                assertEq(
                    keyperModule.isTreeMember(
                        superSafe, subGroupAid[indexGroup]
                    ),
                    true
                );
                // Verify that the new Safe is a superSafe of the previous Safe
                assertEq(
                    keyperModule.isSuperSafe(superSafe, subGroupAid[indexGroup]),
                    true
                );
                // Verify that the new Safe is a member of the root Safe
                assertEq(
                    keyperModule.isTreeMember(rootId, subGroupAid[indexGroup]),
                    true
                );

                // Increment indexGroup
                indexGroup++;
            }
            // Show in consola the level of the new Safe
            if (
                (i > subOldlevels(3, structLevel))
                    && (
                        i.sub(subOldlevels(3, structLevel)).mod(pod(3, structLevel))
                            == 0
                    )
            ) {
                console.log("Level: ", structLevel);
                console.log("i: ", i);
                structLevel++;
            }
        }
    }

    function pod(uint256 base, uint256 exp)
        internal
        pure
        returns (uint256 result)
    {
        result = 1;
        for (uint256 i = 0; i < exp; i++) {
            result *= base;
        }
    }

    function subOldlevels(uint256 base, uint256 level)
        internal
        pure
        returns (uint256 result)
    {
        for (uint256 i = 1; i < level; i++) {
            result += pod(base, i);
        }
    }
}
