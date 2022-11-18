// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelper} from "../src/DenyHelper.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {console} from "forge-std/console.sol";
import {MockedContract} from "./MockedContract.t.sol";
import "./GnosisSafeHelper.t.sol";

contract DenyHelperTest is Test, DenyHelper {
    GnosisSafeHelper public gnosisHelper;
    KeyperModule public keyperModule;
    MockedContract public masterCopyMocked;
    MockedContract public proxyFactoryMocked;

    address public org1;
    address public groupA;
    address public keyperModuleAddr;
    address public keyperRolesDeployed;
    address[] public owners = new address[](5);
    string public rootOrgName;

    // Function called before each test is run
    function setUp() public {
        masterCopyMocked = new MockedContract();
        proxyFactoryMocked = new MockedContract();

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
            address(masterCopyMocked),
            address(proxyFactoryMocked),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        factory.deploy(salt, bytecode);
    }

    function testAddToList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToList(org1, owners);
        assertEq(keyperModule.listCount(org1), owners.length);
        assertEq(keyperModule.getAll(org1).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(org1, owners[i]), true);
        }
    }

    function testRevertInvalidGnosisSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.enableAllowlist(org1);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.addToList(org1, owners);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.addToList(org1, owners);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.dropFromList(org1, owners[2]);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.dropFromList(org1, owners[2]);
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
        keyperModule.addToList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromList(org1, owners[2]);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromList(org1, owners[2]);
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
        keyperModule.addToList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.addToList(org1, owners);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromList(org1, owners[2]);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.dropFromList(org1, owners[2]);
        vm.stopPrank();
    }

    function testRevertIfDenyHelpersDisabled() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        vm.expectRevert(DenyHelper.DenyHelpersDisabled.selector);
        keyperModule.addToList(org1, owners);
        address dropOwner = owners[1];
        vm.expectRevert(DenyHelper.DenyHelpersDisabled.selector);
        keyperModule.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForAllowList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableAllowlist(org1);
        vm.expectRevert(DenyHelper.ListEmpty.selector);
        keyperModule.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForDenyList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableDenylist(org1);
        vm.expectRevert(DenyHelper.ListEmpty.selector);
        keyperModule.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForAllowList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToList(org1, owners);
        address dropOwner = address(0xFFF111);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.dropFromList(org1, dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForDenyList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToList(org1, owners);
        assertEq(keyperModule.listCount(org1), owners.length);
        assertEq(keyperModule.getAll(org1).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(org1, owners[i]), true);
        }
    }

    function testRevertAddToListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.addToList(org1, voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertAddToListInvalidAddress() public {
        listOfInvalidOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.addToList(org1, owners);
        vm.stopPrank();
    }

    function testRevertAddToDuplicateAddress() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        keyperModule.addToList(org1, owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(DenyHelper.UserAlreadyOnList.selector);
        keyperModule.addToList(org1, newOwner);
        vm.stopPrank();
    }

    function testDropFromList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        keyperModule.addToList(org1, owners);

        // Must be Revert if drop not address (0)
        address newOwner = address(0x0);
        vm.expectRevert(DenyHelper.InvalidAddressProvided.selector);
        keyperModule.dropFromList(org1, newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromList(org1, ownerToRemove);
        assertEq(keyperModule.isListed(org1, ownerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromList(org1, secOwnerToRemove);
        assertEq(keyperModule.isListed(org1, secOwnerToRemove), false);
        assertEq(keyperModule.getAll(org1).length, 3);
        vm.stopPrank();
    }

    function testGetPrevUserList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        keyperModule.addToList(org1, owners);
        assertEq(keyperModule.getPrevUser(org1, owners[1]), owners[0]);
        assertEq(keyperModule.getPrevUser(org1, owners[2]), owners[1]);
        assertEq(keyperModule.getPrevUser(org1, owners[3]), owners[2]);
        assertEq(keyperModule.getPrevUser(org1, owners[4]), owners[3]);
        assertEq(keyperModule.getPrevUser(org1, address(0)), owners[4]);
        // SENTINEL_WALLETS
        assertEq(keyperModule.getPrevUser(org1, owners[0]), address(0x1));
        vm.stopPrank();
    }

    function testEnableAllowlist() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist(org1);
        assertEq(keyperModule.allowFeature(org1), true);
        assertEq(keyperModule.denyFeature(org1), false);
        vm.stopPrank();
    }

    function testEnableDenylist() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist(org1);
        assertEq(keyperModule.allowFeature(org1), false);
        assertEq(keyperModule.denyFeature(org1), true);
        vm.stopPrank();
    }

    // ! Test without keyperModule

    function testAddToListNoModule() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        enableAllowlist(org1);
        addToList(org1, owners);
        // assertEq(keyperModule.listCount(org1), owners.length);
        assertEq(getAll(org1).length, owners.length);
        // for (uint256 i = 0; i < owners.length; i++) {
        //     assertEq(keyperModule.isListed(org1, owners[i]), true);
        // }
    }

    // Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name) public {
        vm.startPrank(org);
        keyperModule.registerOrg(name);
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
}
