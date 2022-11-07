// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelper} from "../src/DenyHelper.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import "./GnosisSafeHelper.t.sol";

contract DenyHelperTest is Test {
	GnosisSafeHelper gnosisHelper;
    KeyperModule keyperModule;

    address org1;
    address groupA;
    address keyperModuleAddr;
    address keyperRolesDeployed;
	address[] public owners = new address[](5);
    string rootOrgName;

    // Function called before each test is run
    function setUp() public {
        // Setup Gnosis Helper
        gnosisHelper = new GnosisSafeHelper();
        // Setup of all Safe for Testing
        org1 = gnosisHelper.setupSeveralSafeEnv();
        groupA = gnosisHelper.setupSeveralSafeEnv();
        vm.label(org1, "Org 1");
        vm.label(groupA, "GroupA");

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModule(
            address(0x112233),
            address(0x445566),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        factory.deploy(salt, bytecode);
    }

    function testAddToAllowedList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToAllowedList(org1, owners);
        vm.stopPrank();
        assertEq(keyperModule.allowedCount(org1), 5);
        assertEq(keyperModule.getPrevUser(org1, owners[1], true), owners[0]);
    }

    function testRevertInvalidGnosisSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.enableAllowlist(org1);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.addToAllowedList(org1, owners);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.addToDeniedList(org1, owners);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.dropFromAllowedList(org1, owners[2]);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.dropFromDeniedList(org1, owners[2]);
    }

    function testRevertUnAuthorizedIfCallSuperSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.enableAllowlist(org1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.enableDenylist(org1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToAllowedList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToDeniedList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromAllowedList(org1, owners[2]);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromDeniedList(org1, owners[2]);
        vm.stopPrank();
    }

    function testRevertUnAuthorizedIfCallAnotherSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        address anotherWallet = gnosisHelper.setupSeveralSafeEnv();
        vm.startPrank(anotherWallet);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.enableAllowlist(org1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.enableDenylist(org1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToAllowedList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToDeniedList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromAllowedList(org1, owners[2]);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromDeniedList(org1, owners[2]);
        vm.stopPrank();
    }

	function testRevertIfAllowOrDeniedFeatureIsDisabled() public {
		listOfOwners();
		registerOrgWithRoles(org1, rootOrgName);
		vm.startPrank(org1);
		vm.expectRevert(DenyHelper.AllowedListDisable.selector);
		keyperModule.addToAllowedList(org1, owners);
		vm.expectRevert(DenyHelper.DeniedListDisable.selector);
		keyperModule.addToDeniedList(org1, owners);
		vm.stopPrank();
	}

    function testRevertAddToDeniedListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToDeniedList(org1, voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertAddToDeniedListInvalidAddress() public {
        listOfInvalidOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToDeniedList(org1, owners);
        vm.stopPrank();
    }

    function testRevertAddToDeniedDuplicateAddress() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        keyperModule.addToDeniedList(org1, owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnDeniedList.selector);
        keyperModule.addToDeniedList(org1, newOwner);
        vm.stopPrank();
    }

    function testDropFromDeniedList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        keyperModule.addToDeniedList(org1, owners);

		// Must be Revert if drop not address (0)
		address newOwner = address(0x0);
		vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
		keyperModule.dropFromDeniedList(org1, newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromDeniedList(org1, ownerToRemove);
        assertEq(keyperModule.isDenied(org1, ownerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromDeniedList(org1, secOwnerToRemove);
        assertEq(keyperModule.isDenied(org1, secOwnerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 3);
        vm.stopPrank();
    }

    function testRevertAddToAllowedListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToAllowedList(org1, voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertAddToAllowedListInvalidAddress() public {
        listOfInvalidOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToAllowedList(org1, owners);
        vm.stopPrank();
    }

    function testRevertAddToAllowedDuplicateAddress() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToAllowedList(org1, owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnAllowedList.selector);
        keyperModule.addToAllowedList(org1, newOwner);
        vm.stopPrank();
    }

    function testDropFromAllowedList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToAllowedList(org1, owners);

		// Must be Revert if drop not address (0)
		address newOwner = address(0x0);
		vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
		keyperModule.dropFromAllowedList(org1, newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromAllowedList(org1, ownerToRemove);
        assertEq(keyperModule.isAllowed(org1, ownerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromAllowedList(org1, secOwnerToRemove);
        assertEq(keyperModule.isAllowed(org1, secOwnerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 3);
        vm.stopPrank();
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

	// Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name) public {
        vm.startPrank(org);
        keyperModule.registerOrg(name);
        vm.stopPrank();
    }
}
