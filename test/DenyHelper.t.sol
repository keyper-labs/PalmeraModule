// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelper} from "../src/DenyHelper.sol";
import {Test} from "forge-std/Test.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {DenyHelperMockedContract} from "./mocks/DenyHelperMockedContract.t.sol";

contract DenyHelperTest is Test {
    DenyHelperMockedContract public denyTester;

    address public org1 = address(0xAAAA);
    address[] public owners = new address[](5);

    // Function called before each test is run
    function setUp() public {
        // Deployed for being able to test DenyHelper for itself
        denyTester = new DenyHelperMockedContract();
        // Init owners
        setListOfOwners();
    }

    function testAddToListNoModule() public {
        vm.startPrank(org1);
        denyTester.enableAllowlist(org1);
        denyTester.addToList(org1, owners);
        assertEq(denyTester.listCount(org1), owners.length);
        assertEq(denyTester.getAll(org1).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(denyTester.isListed(org1, owners[i]), true);
        }
    }

    function testRevertAddToListZeroAddressNoModule() public {
        address[] memory voidOwnersArray = new address[](0);
        vm.startPrank(org1);
        denyTester.enableDenylist(org1);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        denyTester.addToList(org1, voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertIfDenyHelpersDisabledNoModule() public {
        vm.startPrank(org1);
        vm.expectRevert(DenyHelper.DenyHelpersDisabled.selector);
        denyTester.addToList(org1, owners);
        address dropOwner = owners[1];
        vm.expectRevert(DenyHelper.DenyHelpersDisabled.selector);
        denyTester.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForAllowListNoModule() public {
        vm.startPrank(org1);
        denyTester.enableAllowlist(org1);
        denyTester.addToList(org1, owners);
        address dropOwner = address(0xFFF111);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        denyTester.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertAddToDuplicateAddressNoModule() public {
        vm.startPrank(org1);
        denyTester.enableDenylist(org1);
        denyTester.addToList(org1, owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnList.selector);
        denyTester.addToList(org1, newOwner);
        vm.stopPrank();
    }

    function testDropFromListNoModule() public {
        vm.startPrank(org1);
        denyTester.enableDenylist(org1);
        denyTester.addToList(org1, owners);

        // Must be Revert if drop not address (0)
        address newOwner = address(0x0);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        denyTester.dropFromList(org1, newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        denyTester.dropFromList(org1, ownerToRemove);
        assertEq(denyTester.isListed(org1, ownerToRemove), false);
        assertEq(denyTester.getAll(org1).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        denyTester.dropFromList(org1, secOwnerToRemove);
        assertEq(denyTester.isListed(org1, secOwnerToRemove), false);
        assertEq(denyTester.getAll(org1).length, 3);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForAllowListNoModule() public {
        vm.startPrank(org1);
        address dropOwner = owners[1];
        denyTester.enableAllowlist(org1);
        vm.expectRevert(DenyHelper.ListEmpty.selector);
        denyTester.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForDenyListNoModule() public {
        vm.startPrank(org1);
        address dropOwner = owners[1];
        denyTester.enableDenylist(org1);
        vm.expectRevert(DenyHelper.ListEmpty.selector);
        denyTester.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testDisableDenyHelper() public {
        vm.startPrank(org1);
        denyTester.enableAllowlist(org1);
        assertEq(denyTester.allowFeature(org1), true);
        assertEq(denyTester.denyFeature(org1), false);

        denyTester.disableDenyHelper(org1);
        assertEq(denyTester.allowFeature(org1), false);
        assertEq(denyTester.denyFeature(org1), false);

        denyTester.enableDenylist(org1);
        assertEq(denyTester.allowFeature(org1), false);
        assertEq(denyTester.denyFeature(org1), true);

        denyTester.disableDenyHelper(org1);
        assertEq(denyTester.allowFeature(org1), false);
        assertEq(denyTester.denyFeature(org1), false);
        vm.stopPrank();
    }

    function setListOfOwners() internal {
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0xDDD);
        owners[4] = address(0xEEE);
    }
}
