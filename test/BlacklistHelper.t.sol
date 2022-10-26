// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {BlacklistHelper} from "../src/BlacklistHelper.sol";

contract BlacklistHelperTest is Test {
    BlacklistHelper public blacklistHelper;
    address[] public owners = new address[](5);

    function setUp() public {
        blacklistHelper = new BlacklistHelper();
    }

    // It should add owners to
    function testAddToWhitelist() public {
        listOfOwners();
        blacklistHelper.addToWhiteList(owners);
        assertEq(blacklistHelper.whitelistedCount(), 5);
        assertEq(blacklistHelper.getPrevUser(owners[1]), owners[0]);
    }

    function testRevertAddToWhitelistZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);

        vm.expectRevert(BlacklistHelper.zeroAddressProvided.selector);
        blacklistHelper.addToWhiteList(voidOwnersArray);
    }

    function testRevertAddToWhitelistInvalidAddress() public {
        listOfInvalidOwners();

        vm.expectRevert(BlacklistHelper.invalidAddressProvided.selector);
        blacklistHelper.addToWhiteList(owners);
    }

    function testRevertAddToWhitelistDuplicateAddress() public {
        listOfOwners();
        blacklistHelper.addToWhiteList(owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(BlacklistHelper.userAlreadyOnWhitelist.selector);
        blacklistHelper.addToWhiteList(newOwner);
    }

    function testDropFromWhitelist() public {
        listOfOwners();
        blacklistHelper.addToWhiteList(owners);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        blacklistHelper.dropFromWhiteList(ownerToRemove);
        assertEq(blacklistHelper.isWhitelisted(ownerToRemove), false);
        assertEq(blacklistHelper.getAllWhilisted().length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        blacklistHelper.dropFromWhiteList(secOwnerToRemove);
        assertEq(blacklistHelper.isWhitelisted(secOwnerToRemove), false);
        assertEq(blacklistHelper.getAllWhilisted().length, 3);
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
