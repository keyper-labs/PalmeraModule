// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./GnosisSafeHelperV2.t.sol";
import {console} from "forge-std/console.sol";

contract KeyperSafeBuilderV2 is Test {
    GnosisSafeHelperV2 public gnosisHelper;

    mapping(string => address) public keyperSafes;

    function setGnosisHelper(GnosisSafeHelperV2 gnosisHelperArg) public {
        gnosisHelper = gnosisHelperArg;
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           groupA1
    function setUpRootOrgAndOneGroup(
        string memory orgNameArg,
        string memory groupA1NameArg
    ) public returns (address, address) {
        bool result = gnosisHelper.registerOrgTx(orgNameArg);
        keyperSafes[orgNameArg] = address(gnosisHelper.gnosisSafe());

        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        keyperSafes[groupA1NameArg] = address(groupSafe);

        address orgAddr = keyperSafes[orgNameArg];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupA1NameArg);

        vm.deal(orgAddr, 100 gwei);
        vm.deal(groupSafe, 100 gwei);

        return (orgAddr, groupSafe);
    }

    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1
    //              |
    //        safeSubGroupA1
    function setupOrgThreeTiersTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory subGroupA1NameArg
    ) public returns (address, address, address) {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgNameArg, groupA1NameArg);

        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        keyperSafes[subGroupA1NameArg] = address(safeSubGroupA1);
        gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, subGroupA1NameArg);

        return (orgAddr, safeGroupA1, safeSubGroupA1);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1
    //              |
    //        safeSubGroupA1
    //              |
    //      safeSubSubGroupA1
    function setupOrgFourTiersTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory subGroupA1NameArg,
        string memory subSubGroupA1NameArg
    ) public returns (address, address, address, address) {
        (address orgAddr, address safeGroupA1, address safeSubGroupA1) =
        setupOrgThreeTiersTree(orgNameArg, groupA1NameArg, subGroupA1NameArg);

        address safeSubSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        keyperSafes[subSubGroupA1NameArg] = address(safeSubSubGroupA1);
        gnosisHelper.createAddGroupTx(
            orgAddr, safeSubGroupA1, subSubGroupA1NameArg
        );

        return (orgAddr, safeGroupA1, safeSubGroupA1, safeSubSubGroupA1);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      groupA1   GroupB
    //        |
    //  subGroupA1
    //      |
    //  SubSubGroupA1
    function setUpBaseOrgTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory groupBNameArg,
        string memory subGroupA1NameArg,
        string memory subSubGroupA1NameArg
    ) public returns (address, address, address, address, address) {
        (
            address orgAddr,
            address safeGroupA1,
            address safeSubGroupA1,
            address safeSubSubGroupA1
        ) = setupOrgFourTiersTree(
            orgNameArg, groupA1NameArg, subGroupA1NameArg, subSubGroupA1NameArg
        );

        (, address safeGroupB) =
            setUpRootOrgAndOneGroup(orgNameArg, groupBNameArg);

        return (
            orgAddr, safeGroupA1, safeGroupB, safeSubGroupA1, safeSubSubGroupA1
        );
    }
}
