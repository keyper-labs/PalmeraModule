// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {console} from "forge-std/console.sol";

contract DenyHelperTest is Test {
    KeyperModule public keyperModule;

    address public keyperModuleAddr;
    address public keyperRolesDeployed;
    address[] public owners = new address[](5);

    function setUp() public {
        // Gnosis safe call / keyperRoles are not used during the tests, no need deployed factory/mastercopy/keyperRoles
        keyperModule = new KeyperModule(
            address(0x112233),
            address(0x445566),
            address(0x786946)
        );
    }

    function testAddToAllowedList() public {
        listOfOwners();
        keyperModule.addToAllowedList(owners);
        assertEq(keyperModule.allowedCount(), owners.length);
        assertEq(keyperModule.getAllAllowed().length, owners.length);
        assertEq(keyperModule.isAllowed(owners[0]), true);
        assertEq(keyperModule.isAllowed(owners[1]), true);
        assertEq(keyperModule.isAllowed(owners[2]), true);
        assertEq(keyperModule.isAllowed(owners[3]), true);
        assertEq(keyperModule.isAllowed(owners[4]), true);
    }

    function testRevertAddToAllowedListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);

        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToAllowedList(voidOwnersArray);
    }

    function testRevertAddToAllowedListInvalidAddress() public {
        listOfInvalidOwners();

        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToAllowedList(owners);
    }

    function testRevertAddToAllowedDuplicateAddress() public {
        listOfOwners();
        keyperModule.addToAllowedList(owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnAllowedList.selector);
        keyperModule.addToAllowedList(newOwner);
    }

    function testDropFromAllowedList() public {
        listOfOwners();
        keyperModule.addToAllowedList(owners);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromAllowedList(ownerToRemove);
        assertEq(keyperModule.isAllowed(ownerToRemove), false);
        assertEq(keyperModule.getAllAllowed().length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromAllowedList(secOwnerToRemove);
        assertEq(keyperModule.isAllowed(secOwnerToRemove), false);
        assertEq(keyperModule.getAllAllowed().length, 3);
    }

    function testAddToDeniedList() public {
        listOfOwners();
        keyperModule.addToDeniedList(owners);
        assertEq(keyperModule.deniedCount(), owners.length);
        assertEq(keyperModule.getAllDenied().length, owners.length);
        assertEq(keyperModule.isDenied(owners[0]), true);
        assertEq(keyperModule.isDenied(owners[1]), true);
        assertEq(keyperModule.isDenied(owners[2]), true);
        assertEq(keyperModule.isDenied(owners[3]), true);
        assertEq(keyperModule.isDenied(owners[4]), true);
    }

    function testRevertAddToDenieddListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);

        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToDeniedList(voidOwnersArray);
    }

    function testRevertAddToDeniedListInvalidAddress() public {
        listOfInvalidOwners();

        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToDeniedList(owners);
    }

    function testRevertAddToDeniedDuplicateAddress() public {
        listOfOwners();
        keyperModule.addToDeniedList(owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = owners[3];

        vm.expectRevert(DenyHelper.UserAlreadyOnDeniedList.selector);
        keyperModule.addToDeniedList(newOwner);
    }

    function testDropFromDeniedList() public {
        listOfOwners();

        keyperModule.addToDeniedList(owners);

        // Must be the address(0xBBB)
        address ownerToRemove = owners[1];

        keyperModule.dropFromDeniedList(ownerToRemove);
        assertEq(keyperModule.isDenied(ownerToRemove), false);
        assertEq(keyperModule.getAllDenied().length, owners.length - 1);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[3];

        keyperModule.dropFromDeniedList(secOwnerToRemove);
        assertEq(keyperModule.isDenied(secOwnerToRemove), false);
        assertEq(keyperModule.getAllDenied().length, owners.length - 2);
    }

    function testGetPrevUserAllowedList() public {
        listOfOwners();

        keyperModule.addToAllowedList(owners);
        assertEq(keyperModule.getPrevUser(owners[1], true), owners[0]);
        assertEq(keyperModule.getPrevUser(owners[2], true), owners[1]);
        assertEq(keyperModule.getPrevUser(owners[3], true), owners[2]);
        assertEq(keyperModule.getPrevUser(owners[4], true), owners[3]);
        assertEq(keyperModule.getPrevUser(address(0), true), owners[4]);
        // SENTINEL_WALLETS
        assertEq(keyperModule.getPrevUser(owners[0], true), address(0x1));
    }

    function testGetPrevUserDeniedList() public {
        listOfOwners();

        keyperModule.addToDeniedList(owners);
        assertEq(keyperModule.getPrevUser(owners[1], false), owners[0]);
        assertEq(keyperModule.getPrevUser(owners[2], false), owners[1]);
        assertEq(keyperModule.getPrevUser(owners[3], false), owners[2]);
        assertEq(keyperModule.getPrevUser(owners[4], false), owners[3]);
        assertEq(keyperModule.getPrevUser(address(0), false), owners[4]);
        // SENTINEL_WALLETS
        assertEq(keyperModule.getPrevUser(owners[0], false), address(0x1));
    }

    function testEnableAllowlist() public {
        keyperModule.enableAllowlist();
        assertEq(keyperModule.allowFeature(), true);
        assertEq(keyperModule.denyFeature(), false);
    }

    function testEnableDenylist() public {
        keyperModule.enableDenylist();
        assertEq(keyperModule.allowFeature(), false);
        assertEq(keyperModule.denyFeature(), true);
    }

    function listOfOwners() internal {
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0xDDD);
        owners[4] = address(0xEEE);
    }

    ///@dev On this function we are able to set an invalid address within some array position
    ///@dev Tested with the address(0), SENTINEL_WALLETS and address(this) on different positions
    function listOfInvalidOwners() internal {
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0x1);
        owners[4] = address(0xEEE);
    }
}
