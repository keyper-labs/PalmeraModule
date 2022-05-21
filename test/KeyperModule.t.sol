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

    // Function called before each test is run
    function setUp() public {
        vm.label(org1, "Org 1");
        vm.label(groupA, "GroupA");
        vm.label(groupB, "GroupB");
        keyperModule = new KeyperModule();
    }

    function testCreateRootOrg() public {
        vm.startPrank(org1);
        string memory name = "Root Org";
        keyperModule.createOrg(name);
        string memory orgname;
        address admin;
        address safe;
        address parent;
        (orgname, admin, safe, parent) = keyperModule.getOrg(org1);
        assertEq(orgname, name);
        assertEq(admin, org1);
        assertEq(safe, org1);
        assertEq(parent, address(0));
    }

    function testAddGroup() public {
        vm.startPrank(org1);
        string memory name = "Root Org";
        keyperModule.createOrg(name);
        vm.stopPrank();
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, org1, "GroupA");
        vm.stopPrank();
        string memory groupName;
        address admin;
        address safe;
        address parent;
        (groupName, admin, safe, parent) = keyperModule.getGroupInfo(org1, groupA);
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(admin, org1);
        assertEq(parent, org1);
    }

    function testExpectOrgNotRegistered() public {
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.OrgNotRegistered.selector);
        keyperModule.addGroup(org1, org1, org1, "GroupA");
    }

    function testExpectParentNotRegistered() public {
        vm.startPrank(org1);
        string memory name = "Root Org";
        keyperModule.createOrg(name);
        vm.stopPrank();
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.ParentNotRegistered.selector);
        keyperModule.addGroup(org1, org2, org1, "GroupA");
    }
}
