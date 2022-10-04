// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

contract KeyperModuleTest is Test {
    KeyperModule keyperModule;

    address org1 = address(0x1);
    address org2 = address(0x2);
    address groupA = address(0xa);
    address groupB = address(0xb);
    address groupC = address(0xc);
    address groupD = address(0xd);
    string rootOrgName;

    // Function called before each test is run
    function setUp() public {
        vm.label(org1, "Org 1");
        vm.label(groupA, "GroupA");
        vm.label(groupB, "GroupB");
        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModule(
            address(0x112233),
            address(0x445566),
            address(0xAEEF)
        );
        rootOrgName = "Root Org";
    }

    function testCreateRootOrg() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        string memory orgname;
        address admin;
        address safe;
        address parent;
        (orgname, admin, safe, parent) = keyperModule.getOrg(org1);
        assertEq(orgname, rootOrgName);
        assertEq(admin, org1);
        assertEq(safe, org1);
        assertEq(parent, address(0));
    }

    function testAddGroup() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        string memory groupName;
        address admin;
        address safe;
        address parent;
        (groupName, admin, safe, parent) = keyperModule.getGroupInfo(
            org1,
            groupA
        );
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(admin, org1);
        assertEq(parent, org1);
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
    }

    function testExpectOrgNotRegistered() public {
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.OrgNotRegistered.selector);
        keyperModule.addGroup(org1, org1, "GroupA");
    }

    function testExpectParentNotRegistered() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.ParentNotRegistered.selector);
        keyperModule.addGroup(org1, groupA, "GroupA");
    }

    function testAddSubGroup() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        keyperModule.addGroup(org1, groupA, "Group B");
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
        assertEq(keyperModule.isChild(org1, groupA, groupB), true);
    }

    // Test tree structure for groups
    //                  org1        org2
    //                  |            |
    //              groupA          groupB
    //                |
    //              groupC
    function testTreeOrgs() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupC);
        keyperModule.addGroup(org1, groupA, "Group C");
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
        assertEq(keyperModule.isChild(org1, groupA, groupC), true);
        vm.stopPrank();
        vm.startPrank(org2);
        keyperModule.registerOrg("RootOrg2");
        vm.stopPrank();
        vm.startPrank(groupB);
        keyperModule.addGroup(org2, org2, "GroupB");
        assertEq(keyperModule.isChild(org2, org2, groupB), true);
    }

    // Test transaction execution
    function testExecKeeperTransaction() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        keyperModule.addGroup(org1, org1, "GroupA");
    }

    // Test is Parent function
    function testIsParent() public {
        vm.startPrank(org1);
        keyperModule.registerOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        keyperModule.addGroup(org1, groupA, "groupB");
        vm.stopPrank();
        vm.startPrank(groupC);
        keyperModule.addGroup(org1, groupB, "GroupC");
        vm.stopPrank();
        vm.startPrank(groupD);
        keyperModule.addGroup(org1, groupC, "groupD");
        assertEq(keyperModule.isParent(org1, org1, groupA), true);
        assertEq(keyperModule.isParent(org1, groupA, groupB), true);
        assertEq(keyperModule.isParent(org1, groupB, groupC), true);
        assertEq(keyperModule.isParent(org1, groupC, groupD), true);
        assertEq(keyperModule.isParent(org1, groupB, groupD), true);
        assertEq(keyperModule.isParent(org1, groupA, groupD), true);
        assertEq(keyperModule.isParent(org1, groupD, groupA), false);
        assertEq(keyperModule.isParent(org1, groupB, groupA), false);
    }
}
