// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./GnosisSafeHelper.t.sol";
import "./ReentrancyAttackHelper.t.sol";
import {Constants} from "../../src/Constants.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {console} from "forge-std/console.sol";

contract KeyperSafeBuilder is Test, Constants {
    KeyperModule public keyperModule;
    GnosisSafeHelper public gnosisHelper;

    mapping(string => address) public keyperSafes;

    function setUpParams(
        KeyperModule keyperModuleArg,
        GnosisSafeHelper gnosisHelperArg
    ) public {
        keyperModule = keyperModuleArg;
        gnosisHelper = gnosisHelperArg;
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           groupA1
    function setUpRootOrgAndOneGroup(
        string memory _orgName,
        string memory _groupName
    ) public returns (address, address) {
        // Set initial safe as a rootOrg
        bool result = gnosisHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        // Create Group calldata
        keyperSafes[_groupName] = address(groupSafe);

        address orgAddr = keyperSafes[_orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, _groupName);

        // Send ETH to org&subgroup
        vm.deal(orgAddr, 100 gwei);
        vm.deal(groupSafe, 100 gwei);

        return (orgAddr, groupSafe);
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
        string memory _orgName,
        string memory _groupA1Name,
        string memory _groupBName,
        string memory _subGroupA1Name,
        string memory _subSubGroupA1Name
    ) public returns (address, address, address, address, address) {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address safeGroupA1 = gnosisHelper.newKeyperSafe(3, 1);
        // Create AddGroup calldata
        keyperSafes[_groupA1Name] = address(safeGroupA1);

        address orgAddr = keyperSafes[_orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, _groupA1Name);

        // Create new safe with setup called while creating contract
        address safeGroupB = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[_groupBName] = address(safeGroupB);

        orgAddr = keyperSafes[_orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, _groupBName);

        // Create new safe with setup called while creating contract
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[_subGroupA1Name] = address(safeSubGroupA1);
        orgAddr = keyperSafes[_orgName];
        result =
            gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, _subGroupA1Name);

        // Create new safe with setup called while creating contract
        address safeSubSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[_subSubGroupA1Name] = address(safeSubSubGroupA1);

        result = gnosisHelper.createAddGroupTx(
            orgAddr, safeSubGroupA1, _subSubGroupA1Name
        );

        return (
            orgAddr, safeGroupA1, safeGroupB, safeSubGroupA1, safeSubSubGroupA1
        );
    }

    function setSafeLeadOfOrg(string memory _orgName)
        public
        returns (address, address)
    {
        bool result = gnosisHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[_orgName], _orgName);
        assertEq(result, true);

        address orgAddr = keyperSafes[_orgName];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, orgAddr, true);
        vm.stopPrank();

        return (orgAddr, userLead);
    }
}
