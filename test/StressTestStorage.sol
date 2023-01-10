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

    // Initial Test for verification of Add subSquad
    function testAddSubSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        address squadBaddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(squadBaddr);
        uint256 squadIdB = keyperModule.addSquad(squadIdA1, squadBName);
        assertEq(keyperModule.isTreeMember(rootId, squadIdA1), true);
        assertEq(keyperModule.isSuperSafe(rootId, squadIdA1), true);
        assertEq(keyperModule.isTreeMember(squadIdA1, squadIdB), true);
        assertEq(keyperModule.isSuperSafe(squadIdA1, squadIdB), true);
        vm.stopPrank();
    }

    // Stress Test for Verification of maximal level when add sub Squad, in a lineal secuencial way
    function testAddSubSquadLinealSecuenceMaxLevel() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](8100);
        uint256[] memory subSquadAid = new uint256[](8100);

        // Assig the Address to first two subSquads
        subSquadAaddr[0] = keyperModule.getSquadSafeAddress(rootId);
        subSquadAaddr[1] = keyperModule.getSquadSafeAddress(squadIdA1);

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;
        subSquadAid[1] = squadIdA1;

        for (uint256 i = 2; i < 8100; i++) {
            // Create a new Safe
            subSquadAaddr[i] = gnosisHelper.newKeyperSafe(3, 1);
            // Start Prank
            vm.startPrank(subSquadAaddr[i]);
            // Add the new Safe as a subSquad
            try keyperModule.addSquad(subSquadAid[i - 1], squadBName) returns (
                uint256 squadId
            ) {
                subSquadAid[i] = squadId;
                // Stop Prank
                vm.stopPrank();
            } catch Error(string memory reason) {
                console.log("Error: ", reason);
            }

            // Verify that the new Safe is a member of tree of the previous Safe
            assertEq(
                keyperModule.isTreeMember(subSquadAid[i - 1], subSquadAid[i]),
                true
            );
            // Verify that the new Safe is a superSafe of the previous Safe
            assertEq(
                keyperModule.isSuperSafe(subSquadAid[i - 1], subSquadAid[i]),
                true
            );
            // Verify that the new Safe is a member of the root Tree
            assertEq(keyperModule.isTreeMember(rootId, subSquadAid[i]), true);
            // Show in consola the level of the new Safe
            console.log("Level: ", i);
        }
    }

    // Stress Test for Verification of maximal level when add three sub Squad, in a lineal secuencial way
    // Struct of Org
    //                Root
    //          /      |      \
    // 	   	   A1     A2      A3
    // 	      /|\     /|\    /|\
    // 	     B1B2B3  B1B2B3 B1B2B3 ........
    function testAddThreeSubSquadLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 3, 30000);
    }

    // Stress Test for Verification of maximal level when add Four sub Squad, in a lineal secuencial way
    // Struct of Org
    //                       Root
    //          ┌---------┬---------┬----------┐
    // 	   	    A1        A2       A3         A4
    // 	       /|\\      /|\\     /|\\       /|\\
    // 	     B1B2B3B4  B1B2B3B4  B1B2B3B4  B1B2B3B4
    function testAddFourthSubSquadLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 4, 22000);
    }

    // Stress Test for Verification of maximal level when add Five sub Squad, in a lineal secuencial way
    // Struct of Org
    //                                Root
    //           ┌----------┬-----------┬-----------┬-----------┐
    // 	   	     A1         A2          A3          A4          A5
    // 	       /|\\\       /|\\\       /|\\\      /|\\\        /|\\\
    // 	     B1B2B3B4B5  B1B2B3B4B5  B1B2B3B4B5 B1B2B3B4B5   B1B2B3B4B5
    function testAddFifthSubSquadLinealSecuenceMaxLevel() public {
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        createTreeStressTest("RootOrg", "RootOrg", orgSafe, orgSafe, 5, 20000);
    }

    function testSeveralsSmallOrgsSquadSecuenceMaxLevel() public {
        setUp();
        address orgSafe = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe1 = gnosisHelper.newKeyperSafe(3, 1);
        address orgSafe2 = gnosisHelper.newKeyperSafe(3, 1);
        console.log("Test Severals Small Orgs Squad Secuence Max Level");
        console.log("Squad of 3 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg31", "RootOrg31", orgSafe, orgSafe, 3, 1100
        );
        console.log("Squad of 4 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg41", "RootOrg41", orgSafe1, orgSafe1, 4, 1400
        );
        console.log("Squad of 5 Members");
        console.log("---------------------");
        createTreeStressTest(
            "RootOrg51", "RootOrg51", orgSafe2, orgSafe2, 5, 4000
        );
    }

    function testSeveralsBigOrgsSquadSecuenceMaxLevel() public {
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

    function testFullOrgSquadSecuenceMaxLevel() public {
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
            rootId = keyperModule.getSquadIdBySafe(org, rootSafe);
        } else {
            gnosisHelper.updateSafeInterface(orgSafe);
            bool result = gnosisHelper.registerOrgTx(OrgName);
            assertEq(result, true);
            rootId = keyperModule.getSquadIdBySafe(org, orgSafe);
        }

        // Array of Address for the subSquads
        address[] memory subSquadAaddr = new address[](
            safeWallets.mul(members)
        );
        uint256[] memory subSquadAid = new uint256[](safeWallets.mul(members));
        uint256[] memory level = new uint256[](safeWallets);
        uint256 indexLevel;
        uint256 indexSquad;

        // Assig the Id to first two subSquads
        subSquadAid[0] = rootId;

        // Assign first level
        level[indexLevel] = 0;
        indexSquad = members.sub(1);
        uint256 structLevel = 1;
        for (uint256 i = 0; i < safeWallets.div(members); i++) {
            // SuperSafe of Iteration
            uint256 superSafe = subSquadAid[level[i]];
            for (uint256 j = 0; j < members; j++) {
                // Create a new Safe
                subSquadAaddr[indexSquad] = gnosisHelper.newKeyperSafe(3, 1);
                // Start Prank
                vm.startPrank(subSquadAaddr[indexSquad]);
                // Add the new Safe as a subSquad
                try keyperModule.addSquad(superSafe, squadA1Name) returns (
                    uint256 squadId
                ) {
                    subSquadAid[indexSquad] = squadId;
                    // Stop Prank
                    vm.stopPrank();
                } catch Error(string memory reason) {
                    console.log("Error: ", reason);
                }

                // Verify that the new Safe is a member of the previous Safe
                assertEq(
                    keyperModule.isTreeMember(
                        superSafe, subSquadAid[indexSquad]
                    ),
                    true
                );
                // Verify that the new Safe is a superSafe of the previous Safe
                assertEq(
                    keyperModule.isSuperSafe(superSafe, subSquadAid[indexSquad]),
                    true
                );
                // Verify that the new Safe is a member of the root Safe
                assertEq(
                    keyperModule.isTreeMember(rootId, subSquadAid[indexSquad]),
                    true
                );
                // Only increment indexLevel if is the first Safe of the level
                if (j == 0) {
                    // Assign next level
                    indexLevel++;
                    level[indexLevel] = indexSquad;
                }

                // Increment indexSquad
                indexSquad++;

                uint256 subOldlevel = subOldlevels(members, structLevel);
                uint256 safeLevel = pod(members, structLevel);
                // Show in consola the level of the new Safe
                if (
                    (indexLevel.sub(1) > subOldlevel)
                        && (indexLevel.sub(1).sub(subOldlevel).mod(safeLevel) == 0)
                ) {
                    console.log("Level: ", structLevel + 2);
                    console.log("indexSquad / Amount of Safe: ", indexSquad + 1);
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
