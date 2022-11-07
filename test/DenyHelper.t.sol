// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelper} from "../src/DenyHelper.sol";
import {KeyperModuleTest, Test} from "./KeyperModule.t.sol";

contract DenyHelperTest is Test, KeyperModuleTest {
    // KeyperModule public keyperModule;

    // address public keyperModuleAddr;
    // address public keyperRolesDeployed;
    address[] public owners = new address[](5);

    // function setUp() public {
    //     // Gnosis safe call / keyperRoles are not used during the tests, no need deployed factory/mastercopy/keyperRoles
    //     // keyperModule = new KeyperModule(
    //     //     address(0x112233),
    //     //     address(0x445566),
    //     //     address(0x786946)
    //     // );
    // }

    function testAddToAllowedList() public {
        listOfOwners();
		registerOrgWithRoles(org1,rootOrgName);
        keyperModule.addToAllowedList(org1, owners);
        assertEq(keyperModule.allowedCount(org1), 5);
        assertEq(keyperModule.getPrevUser(org1, owners[1], true), owners[0]);
    }

    function testRevertAddToAllowedListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
		registerOrgWithRoles(org1,rootOrgName);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToAllowedList(org1, voidOwnersArray);
    }

    function testRevertAddToAllowedListInvalidAddress() public {
        listOfInvalidOwners();
		registerOrgWithRoles(org1,rootOrgName);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToAllowedList(org1, owners);
    }

    function testRevertAddToAllowedDuplicateAddress() public {
        listOfOwners();
		registerOrgWithRoles(org1,rootOrgName);
        keyperModule.addToAllowedList(org1, owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnAllowedList.selector);
        keyperModule.addToAllowedList(org1, newOwner);
    }

    function testDropFromAllowedList() public {
        listOfOwners();
		registerOrgWithRoles(org1,rootOrgName);
        keyperModule.addToAllowedList(org1, owners);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromAllowedList(org1, ownerToRemove);
        assertEq(keyperModule.isAllowed(org1, ownerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromAllowedList(org1,secOwnerToRemove);
        assertEq(keyperModule.isAllowed(org1,secOwnerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 3);
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
