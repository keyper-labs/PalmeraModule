// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelperV2} from "../src/DenyHelperV2.sol";
import {Test} from "forge-std/Test.sol";
import {KeyperModuleV2} from "../src/KeyperModuleV2.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRolesV2} from "../src/KeyperRolesV2.sol";
import {console} from "forge-std/console.sol";
import {MockedContract} from "./mocks/MockedContract.t.sol";
import "./helpers/GnosisSafeHelperV2.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

contract DenyHelperKeyperModuleTest is Test {
    GnosisSafeHelperV2 public gnosisHelper;
    KeyperModuleV2 public keyperModule;
    MockedContract public masterCopyMocked;
    MockedContract public proxyFactoryMocked;

    address public org1;
    address public groupA;
    address public keyperModuleAddr;
    address public keyperRolesDeployed;
    address[] public owners = new address[](5);
    string public rootOrgName;
    bytes32 orgId;
    uint256 RootOrgId;

    // Function called before each test is run
    function setUp() public {
        masterCopyMocked = new MockedContract();
        proxyFactoryMocked = new MockedContract();

        // Setup Gnosis Helper
        gnosisHelper = new GnosisSafeHelperV2();
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
        keyperModule = new KeyperModuleV2(
            address(masterCopyMocked),
            address(proxyFactoryMocked),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        orgId = keccak256(abi.encodePacked(rootOrgName));

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode = abi.encodePacked(
            vm.getCode("KeyperRolesV2.sol:KeyperRolesV2"), args
        );

        factory.deploy(salt, bytecode);
    }

    function testAddToList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.listCount(orgId), owners.length);
        assertEq(keyperModule.getAll(orgId).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(orgId, owners[i]), true);
        }
    }

    function testRevertInvalidGnosisSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        // EAO Address (Not Safe)
        vm.startPrank(owners[0]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidGnosisSafe.selector, owners[0])
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
        // Zero Address
        address ZeroAddress = address(0);
        vm.startPrank(ZeroAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, ZeroAddress
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
        // Sentinal Address
        address SentinalAddress = address(0x1);
        vm.startPrank(SentinalAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, SentinalAddress
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    function testRevertInvalidGnosisRootSafe() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(RootOrgId, "GroupA");
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    function testRevertIfCallAnotherSafeNotRegister() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        address anotherWallet = gnosisHelper.setupSeveralSafeEnv();
        vm.startPrank(anotherWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    function testRevertIfDenyHelpersDisabled() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        vm.expectRevert(Errors.DenyHelpersDisabled.selector);
        keyperModule.addToList(owners);
        address dropOwner = owners[1];
        vm.expectRevert(Errors.DenyHelpersDisabled.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForAllowList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableAllowlist();
        vm.expectRevert(Errors.ListEmpty.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForDenyList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.ListEmpty.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForAllowList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        address dropOwner = address(0xFFF111);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForDenyList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.listCount(orgId), owners.length);
        assertEq(keyperModule.getAll(orgId).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(orgId, owners[i]), true);
        }
    }

    function testRevertAddToListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.addToList(voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertAddToListInvalidAddress() public {
        listOfInvalidOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.addToList(owners);
        vm.stopPrank();
    }

    function testRevertAddToDuplicateAddress() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        keyperModule.addToList(owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(Errors.UserAlreadyOnList.selector);
        keyperModule.addToList(newOwner);
        vm.stopPrank();
    }

    function testDropFromList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        keyperModule.addToList(owners);

        // Must be Revert if drop not address (0)
        address newOwner = address(0x0);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.dropFromList(newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        keyperModule.dropFromList(ownerToRemove);
        assertEq(keyperModule.isListed(orgId, ownerToRemove), false);
        assertEq(keyperModule.getAll(orgId).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromList(secOwnerToRemove);
        assertEq(keyperModule.isListed(orgId, secOwnerToRemove), false);
        assertEq(keyperModule.getAll(orgId).length, 3);
        vm.stopPrank();
    }

    function testGetPrevUserList() public {
        listOfOwners();
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.getPrevUser(orgId, owners[1]), owners[0]);
        assertEq(keyperModule.getPrevUser(orgId, owners[2]), owners[1]);
        assertEq(keyperModule.getPrevUser(orgId, owners[3]), owners[2]);
        assertEq(keyperModule.getPrevUser(orgId, owners[4]), owners[3]);
        assertEq(keyperModule.getPrevUser(orgId, address(0)), owners[4]);
        // SENTINEL_WALLETS
        assertEq(keyperModule.getPrevUser(orgId, owners[0]), address(0x1));
        vm.stopPrank();
    }

    function testEnableAllowlist() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        assertEq(keyperModule.allowFeature(orgId), true);
        assertEq(keyperModule.denyFeature(orgId), false);
        vm.stopPrank();
    }

    function testEnableDenylist() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        assertEq(keyperModule.allowFeature(orgId), false);
        assertEq(keyperModule.denyFeature(orgId), true);
        vm.stopPrank();
    }

    // Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name) public {
        vm.startPrank(org);
        RootOrgId = keyperModule.registerOrg(name);
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
