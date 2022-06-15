// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";


contract KeyperModuleTest is Test, KeyperModule {
    KeyperModule keyperModule;

    address org1 = address(0x001);
    address org2 = address(0x002);
    address groupA = address(0x000a);
    address groupB = address(0x000b);
    string rootOrgName;

    // Function called before each test is run
    function setUp() public {
        vm.label(org1, "Org 1");
        vm.label(groupA, "GroupA");
        vm.label(groupB, "GroupB");
        keyperModule = new KeyperModule();
        rootOrgName = "Root Org";
    }

    function testCreateRootOrg() public {
        vm.startPrank(org1);
        keyperModule.createOrg(rootOrgName);
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
        keyperModule.createOrg(rootOrgName);
        keyperModule.addGroup(org1, groupA, org1, org1, "GroupA");
        string memory groupName;
        address admin;
        address safe;
        address parent;
        (groupName, admin, safe, parent) = keyperModule.getGroupInfo(org1, groupA);
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(admin, org1);
        assertEq(parent, org1);
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
    }

    function testExpectOrgNotRegistered() public {
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.OrgNotRegistered.selector);
        keyperModule.addGroup(org1, groupA, org1, org1, "GroupA");
    }

    function testExpectParentNotRegistered() public {
        vm.startPrank(org1);
        keyperModule.createOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.ParentNotRegistered.selector);
        keyperModule.addGroup(org1, groupA, org2, org1, "GroupA");
    }

    function testExpectAdminNotRegistered() public {
        vm.startPrank(org1);
        keyperModule.createOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.AdminNotRegistered.selector);
        keyperModule.addGroup(org1, groupA, org1, org2, "GroupA");
    }

    function testAddSubGroup() public {
        vm.startPrank(org1);
        keyperModule.createOrg(rootOrgName);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, groupA, org1, org1, "GroupA");
        keyperModule.addGroup(org1, groupA, groupA, org1, "Group B");

    }
}
