// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {SigningUtils} from "../src/SigningUtils.sol";
import {DeployHelper} from "./helpers/DeployHelper.t.sol";
import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {console} from "forge-std/console.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

/// @title SkipStressTestStorage
/// @custom:security-contact general@palmeradao.xyz
contract SkipStressTestStorage is DeployHelper, SigningUtils {
    using SafeMath for uint256;

    function setUp() public {
        deployAllContracts(500000);
    }

    // ! ********************* Stress Test Storage ***********************

    // Initial Test for verification of Add subSafe
    function testAddSubSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);
        address safeBaddr = safeHelper.newPalmeraSafe(4, 2);
        vm.startPrank(safeBaddr);
        uint256 safeIdB = palmeraModule.addSafe(safeIdA1, safeBName);
        assertEq(palmeraModule.isTreeMember(rootId, safeIdA1), true);
        assertEq(palmeraModule.isSuperSafe(rootId, safeIdA1), true);
        assertEq(palmeraModule.isTreeMember(safeIdA1, safeIdB), true);
        assertEq(palmeraModule.isSuperSafe(safeIdA1, safeIdB), true);
        vm.stopPrank();
    }

    // Stress Test for Verification of maximal level when add sub Safe, in a lineal secuencial way
    function testAddSubSafeLinealSecuenceMaxLevel() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](8100);
        uint256[] memory subSafeAid = new uint256[](8100);

        // Assig the Address to first two subSafes
        subSafeAaddr[0] = palmeraModule.getSafeAddress(rootId);
        subSafeAaddr[1] = palmeraModule.getSafeAddress(safeIdA1);

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;
        subSafeAid[1] = safeIdA1;

        for (uint256 i = 2; i < 8100; ++i) {
            // Create a new Safe
            subSafeAaddr[i] = safeHelper.newPalmeraSafe(3, 1);
            // Start Prank
            vm.startPrank(subSafeAaddr[i]);
            // Add the new Safe as a subSafe
            try palmeraModule.addSafe(subSafeAid[i - 1], safeBName) returns (
                uint256 safeId
            ) {
                subSafeAid[i] = safeId;
                // Stop Prank
                vm.stopPrank();
            } catch Error(string memory reason) {
                console.log("Error: ", reason);
            }

            // Verify that the new Safe is a member of tree of the previous Safe
            assertEq(
                palmeraModule.isTreeMember(subSafeAid[i - 1], subSafeAid[i]),
                true
            );
            // Verify that the new Safe is a superSafe of the previous Safe
            assertEq(
                palmeraModule.isSuperSafe(subSafeAid[i - 1], subSafeAid[i]),
                true
            );
            // Verify that the new Safe is a member of the root Tree
            assertEq(palmeraModule.isTreeMember(rootId, subSafeAid[i]), true);
            // Show in consola the level of the new Safe
            console.log("Level: ", i);
        }
    }

    // Stress Test for Verification of maximal level when add three sub Safe, in a lineal secuencial way
    // Struct of Org
    //                Root
    //          /      |      \
    // 	   	   A1     A2      A3
    // 	      /|\     /|\    /|\
    // 	     B1B2B3  B1B2B3 B1B2B3 ........
    function testAddThreeSubSafeLinealSecuenceMaxLevel() public {
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 3, 30000);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(orgSafe);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);
        console.log("All Org Removed");
    }

    // Stress Test for Verification of maximal level when add Four sub Safe, in a lineal secuencial way
    // Struct of Org
    //                       Root
    //          ┌---------┬---------┬----------┐
    // 	   	    A1        A2       A3         A4
    // 	       /|\\      /|\\     /|\\       /|\\
    // 	     B1B2B3B4  B1B2B3B4  B1B2B3B4  B1B2B3B4
    function testAddFourthSubSafeLinealSecuenceMaxLevel() public {
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 4, 22000);
    }

    // Stress Test for Verification of maximal level when add Five sub Safe, in a lineal secuencial way
    // Struct of Org
    //                                Root
    //           ┌----------┬-----------┬-----------┬-----------┐
    // 	   	     A1         A2          A3          A4          A5
    // 	       /|\\\       /|\\\       /|\\\      /|\\\        /|\\\
    // 	     B1B2B3B4B5  B1B2B3B4B5  B1B2B3B4B5 B1B2B3B4B5   B1B2B3B4B5
    function testAddFifthSubSafeLinealSecuenceMaxLevel() public {
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 5, 20000);
    }

    function testSeveralsSmallOrgsSafeSecuenceMaxLevel() public {
        setUp();
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        address orgSafe1 = safeHelper.newPalmeraSafe(3, 1);
        address orgSafe2 = safeHelper.newPalmeraSafe(3, 1);
        console.log("Test Severals Small Orgs Safe Secuence Max Level");
        console.log("Safe of 3 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg31", "RootOrg31", orgSafe, orgSafe, 3, 1100
        );
        console.log("Safe of 4 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg41", "RootOrg41", orgSafe1, orgSafe1, 4, 1400
        );
        console.log("Safe of 5 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg51", "RootOrg51", orgSafe2, orgSafe2, 5, 4000
        );
    }

    function testSeveralsBigOrgsSafeSecuenceMaxLevel() public {
        setUp();
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        address orgSafe1 = safeHelper.newPalmeraSafe(3, 1);
        address orgSafe2 = safeHelper.newPalmeraSafe(3, 1);
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

    function testFullOrgSafeSecuenceMaxLevel() public {
        setUp();
        address orgSafe = safeHelper.newPalmeraSafe(3, 1);
        address rootSafe1 = safeHelper.newPalmeraSafe(3, 1);
        address rootSafe2 = safeHelper.newPalmeraSafe(3, 1);
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
            (palmeraModule.isOrgRegistered(org)) && (orgSafe != rootSafe)
                && (
                    keccak256(abi.encodePacked(RootSafeName))
                        != keccak256(abi.encodePacked(OrgName))
                )
        ) {
            safeHelper.updateSafeInterface(orgSafe);
            bool result = safeHelper.createRootSafeTx(rootSafe, RootSafeName);
            assertEq(result, true);
            rootId = palmeraModule.getSafeIdBySafe(org, rootSafe);
        } else {
            safeHelper.updateSafeInterface(orgSafe);
            bool result = safeHelper.registerOrgTx(OrgName);
            assertEq(result, true);
            rootId = palmeraModule.getSafeIdBySafe(org, orgSafe);
        }

        // Array of Address for the subSafes
        address[] memory subSafeAaddr = new address[](safeWallets.mul(members));
        uint256[] memory subSafeAid = new uint256[](safeWallets.mul(members));
        uint256[] memory level = new uint256[](safeWallets);
        uint256 indexLevel;
        uint256 indexSafe;

        // Assig the Id to first two subSafes
        subSafeAid[0] = rootId;

        // Assign first level
        level[indexLevel] = 0;
        indexSafe = members.sub(1);
        uint256 structLevel = 1;
        for (uint256 i; i < safeWallets.div(members); ++i) {
            // SuperSafe of Iteration
            uint256 superSafe = subSafeAid[level[i]];
            for (uint256 j; j < members; ++j) {
                // Create a new Safe
                subSafeAaddr[indexSafe] = safeHelper.newPalmeraSafe(3, 1);
                // Start Prank
                vm.startPrank(subSafeAaddr[indexSafe]);
                // Add the new Safe as a subSafe
                try palmeraModule.addSafe(superSafe, safeA1Name) returns (
                    uint256 safeId
                ) {
                    subSafeAid[indexSafe] = safeId;
                    // Stop Prank
                    vm.stopPrank();
                } catch Error(string memory reason) {
                    console.log("Error: ", reason);
                }

                // Verify that the new Safe is a member of the previous Safe
                assertEq(
                    palmeraModule.isTreeMember(superSafe, subSafeAid[indexSafe]),
                    true
                );
                // Verify that the new Safe is a superSafe of the previous Safe
                assertEq(
                    palmeraModule.isSuperSafe(superSafe, subSafeAid[indexSafe]),
                    true
                );
                // Verify that the new Safe is a member of the root Safe
                assertEq(
                    palmeraModule.isTreeMember(rootId, subSafeAid[indexSafe]),
                    true
                );
                // Only increment indexLevel if is the first Safe of the level
                if (j == 0) {
                    // Assign next level
                    indexLevel++;
                    level[indexLevel] = indexSafe;
                }

                // Increment indexSafe
                indexSafe++;

                uint256 subOldlevel = subOldlevels(members, structLevel);
                uint256 safeLevel = pod(members, structLevel);
                // Show in consola the level of the new Safe
                if (
                    (indexLevel.sub(1) > subOldlevel)
                        && (indexLevel.sub(1).sub(subOldlevel).mod(safeLevel) == 0)
                ) {
                    console.log("Level: ", structLevel + 2);
                    console.log("indexSafe / Amount of Safe: ", indexSafe + 1);
                    console.log("indexLevel: ", indexLevel);
                    console.log("SubOldLevels: ", subOldlevel);
                    console.log(
                        "Safe Helpers Owners: ", safeHelper.getOwnersUsed()
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
        for (uint256 i; i < exp; ++i) {
            result *= base;
        }
    }

    function subOldlevels(uint256 base, uint256 level)
        internal
        pure
        returns (uint256 result)
    {
        for (uint256 i = 1; i < level; ++i) {
            result += pod(base, i);
        }
    }
}
