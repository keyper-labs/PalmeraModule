// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {console} from "forge-std/console.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

contract StressTestStorage is DeployHelper, SigningUtils {
    using SafeMath for uint256;

    function setUp() public {
        deployAllContracts(500000);
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

            // Verify that the new Safe is a member of tree of the previous Safe
            assertEq(
                keyperModule.isTreeMember(subGroupAid[i - 1], subGroupAid[i]),
                true
            );
            // Verify that the new Safe is a superSafe of the previous Safe
            assertEq(
                keyperModule.isSuperSafe(subGroupAid[i - 1], subGroupAid[i]),
                true
            );
            // Verify that the new Safe is a member of the root Tree
            assertEq(keyperModule.isTreeMember(rootId, subGroupAid[i]), true);
            // Show in consola the level of the new Safe
            console.log("Level: ", i);
        }
    }

    // Stress Test for Verification of maximal level when add three sub Group, in a lineal secuencial way
    // Struct of Org
    //                Root
    //          /      |      \
    // 	   	   A1     A2      A3
    // 	      /|\     /|\    /|\
    // 	     B1B2B3  B1B2B3 B1B2B3 ........
    function testAddThreeSubGroupLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 3, 30000);

        /// Remove Whole Tree A
        gnosisHelper.updateSafeInterface(orgSafe);
        bool result = gnosisHelper.createRemoveWholeTreeTx();
        assertTrue(result);
        console.log("All Org Removed");
    }

    // Stress Test for Verification of maximal level when add Four sub Group, in a lineal secuencial way
    // Struct of Org
    //                       Root
    //          ┌---------┬---------┬----------┐
    // 	   	    A1        A2       A3         A4
    // 	       /|\\      /|\\     /|\\       /|\\
    // 	     B1B2B3B4  B1B2B3B4  B1B2B3B4  B1B2B3B4
    function testAddFourthSubGroupLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 4, 22000);
    }

    // Stress Test for Verification of maximal level when add Five sub Group, in a lineal secuencial way
    // Struct of Org
    //                                Root
    //           ┌----------┬-----------┬-----------┬-----------┐
    // 	   	     A1         A2          A3          A4          A5
    // 	       /|\\\       /|\\\       /|\\\      /|\\\        /|\\\
    // 	     B1B2B3B4B5  B1B2B3B4B5  B1B2B3B4B5 B1B2B3B4B5   B1B2B3B4B5
    function testAddFifthSubGroupLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 5, 20000);
    }

    function testSeveralsSmallOrgsGroupSecuenceMaxLevel() public {
        setUp();
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe1 = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe2 = gnosisHelper.newKeyperSafe(3, 1);
        console.log("Test Severals Small Orgs Group Secuence Max Level");
        console.log("Group of 3 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg31", "RootOrg31", orgSafe, orgSafe, 3, 1100
        );
        console.log("Group of 4 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg41", "RootOrg41", orgSafe1, orgSafe1, 4, 1400
        );
        console.log("Group of 5 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg51", "RootOrg51", orgSafe2, orgSafe2, 5, 4000
        );
    }

    function testSeveralsBigOrgsGroupSecuenceMaxLevel() public {
        setUp();
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe1 = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe2 = gnosisHelper.newKeyperSafe(3, 1);
        console.log("Full Org 1");
        console.log("---------------------");
        createTreeStressTest("RootOrg3", "RootOrg3", orgSafe, orgSafe, 3, 30000);
        console.log("Full Org 2");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg4", "RootOrg4", orgSafe1, orgSafe1, 4, 22000
        );
        console.log("Full Org 3");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg5", "RootOrg5", orgSafe2, orgSafe2, 5, 20000
        );
    }

    function testFullOrgGroupSecuenceMaxLevel() public {
        setUp();
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        address rootSafe1 = gnosisHelper.newKeyperSafe(3, 1);
        address rootSafe2 = gnosisHelper.newKeyperSafe(3, 1);
        console.log("Full Org 2");
        console.log("---------------------");
        createTreeStressTest("RootOrg2", "RootOrg2", orgSafe, orgSafe, 3, 30000);
        console.log("Root Safe 1");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg2", "RootSafe1", orgSafe, rootSafe1, 4, 22000
        );
        console.log("Root Safe 2");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg2", "RootSafe2", orgSafe, rootSafe2, 5, 20000
        );
    }

    function createTreeStressTest(
        string memory OrgName,
        string memory RootSafeName,
        address orgSafe,
        address rootSafe,
        uint256 members,
        uint256 safeWallets
    ) public {
        uint256 rootId;
        bytes32 org = bytes32(keccak256(abi.encodePacked(OrgName)));
        if (
            (keyperModule.isOrgRegistered(org)) && (orgSafe != rootSafe)
                && (
                    keccak256(abi.encodePacked(RootSafeName))
                        != keccak256(abi.encodePacked(OrgName))
                )
        ) {
            gnosisHelper.updateSafeInterface(orgSafe);
            bool result = gnosisHelper.createRootSafeTx(rootSafe, RootSafeName);
            assertEq(result, true);
            rootId = keyperModule.getGroupIdBySafe(org, rootSafe);
            vm.startPrank(orgSafe);
            keyperModule.updateDepthTreeLimit(50);
            vm.stopPrank();
        } else {
            gnosisHelper.updateSafeInterface(orgSafe);
            bool result = gnosisHelper.registerOrgTx(OrgName);
            assertEq(result, true);
            rootId = keyperModule.getGroupIdBySafe(org, orgSafe);
            vm.startPrank(orgSafe);
            keyperModule.updateDepthTreeLimit(50);
            vm.stopPrank();
        }

        // Array of Address for the subGroups
        address[] memory subGroupAaddr = new address[](
            safeWallets.mul(members)
        );
        uint256[] memory subGroupAid = new uint256[](safeWallets.mul(members));
        uint256[] memory level = new uint256[](safeWallets);
        uint256 indexLevel;
        uint256 indexGroup;

        // Assig the Id to first two subGroups
        subGroupAid[0] = rootId;

        // Assign first level
        level[indexLevel] = 0;
        indexGroup = members.sub(1);
        uint256 structLevel = 1;
        for (uint256 i = 0; i < safeWallets.div(members); i++) {
            // SuperSafe of Iteration
            uint256 superSafe = subGroupAid[level[i]];
            for (uint256 j = 0; j < members; j++) {
                // Create a new Safe
                subGroupAaddr[indexGroup] = gnosisHelper.newKeyperSafe(3, 1);
                // Start Prank
                vm.startPrank(subGroupAaddr[indexGroup]);
                // Add the new Safe as a subGroup
                try keyperModule.addGroup(superSafe, groupA1Name) returns (
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
                // Only increment indexLevel if is the first Safe of the level
                if (j == 0) {
                    // Assign next level
                    indexLevel++;
                    level[indexLevel] = indexGroup;
                }

                // Increment indexGroup
                indexGroup++;

                uint256 subOldlevel = subOldlevels(members, structLevel);
                uint256 safeLevel = pod(members, structLevel);
                // Show in consola the level of the new Safe
                if (
                    (indexLevel.sub(1) > subOldlevel)
                        && (indexLevel.sub(1).sub(subOldlevel).mod(safeLevel) == 0)
                ) {
                    console.log("Level: ", structLevel + 2);
                    console.log("indexGroup / Amount of Safe: ", indexGroup + 1);
                    console.log("indexLevel: ", indexLevel);
                    console.log("SubOldLevels: ", subOldlevel);
                    console.log(
                        "Gnosis Helpers Owners: ", gnosisHelper.getOwnersUsed()
                    );
                    structLevel++;
                }
            }
        }
    }

    function pod(uint256 base, uint256 exp)
        internal
        pure
        returns (uint256 result)
    {
        result = 1;
        if (exp == 0) {
            return result;
        }
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
