// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

contract DenyHelperKeyperModuleTest is DeployHelper {
    address org1;
    address squadA;
    address[] public owners = new address[](5);
    uint256 RootOrgId;
    uint256 squadIdA1;

    // Function called before each test is run
    function setUp() public {
        // Initial Deploy Contracts
        deployAllContracts(60);
        // Setup of all Safe for Testing
        // org1 = gnosisHelper.setupSeveralSafeEnv(30);
        // squadA = gnosisHelper.setupSeveralSafeEnv(30);
        (RootOrgId, squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        org1 = keyperModule.getSquadSafeAddress(RootOrgId);
        squadA = keyperModule.getSquadSafeAddress(squadIdA1);
        vm.label(org1, "Org 1");
        vm.label(squadA, "SquadA");
    }

    function testAddToList() public {
        listOfOwners();
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.listCount(orgHash), owners.length);
        assertEq(keyperModule.getAll(orgHash).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(orgHash, owners[i]), true);
        }
    }

    function testRevertInvalidGnosisSafe() public {
        listOfOwners();
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
        vm.startPrank(squadA);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA
            )
        );
        keyperModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    function testRevertIfCallAnotherSafeNotRegistered() public {
        listOfOwners();
        address anotherWallet = gnosisHelper.setupSeveralSafeEnv(30);
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
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableAllowlist();
        vm.expectRevert(Errors.ListEmpty.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfListEmptyForDenyList() public {
        listOfOwners();
        vm.startPrank(org1);
        address dropOwner = owners[1];
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.ListEmpty.selector);
        keyperModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    function testRevertIfInvalidAddressProvidedForAllowList() public {
        listOfOwners();
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
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.listCount(orgHash), owners.length);
        assertEq(keyperModule.getAll(orgHash).length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(keyperModule.isListed(orgHash, owners[i]), true);
        }
    }

    function testRevertAddToListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.addToList(voidOwnersArray);
        vm.stopPrank();
    }

    function testRevertAddToListInvalidAddress() public {
        listOfInvalidOwners();
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.addToList(owners);
        vm.stopPrank();
    }

    function testRevertAddToDuplicateAddress() public {
        listOfOwners();
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
        assertEq(keyperModule.isListed(orgHash, ownerToRemove), false);
        assertEq(keyperModule.getAll(orgHash).length, 4);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        keyperModule.dropFromList(secOwnerToRemove);
        assertEq(keyperModule.isListed(orgHash, secOwnerToRemove), false);
        assertEq(keyperModule.getAll(orgHash).length, 3);
        vm.stopPrank();
    }

    function testGetPrevUserList() public {
        listOfOwners();
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        keyperModule.addToList(owners);
        assertEq(keyperModule.getPrevUser(orgHash, owners[1]), owners[0]);
        assertEq(keyperModule.getPrevUser(orgHash, owners[2]), owners[1]);
        assertEq(keyperModule.getPrevUser(orgHash, owners[3]), owners[2]);
        assertEq(keyperModule.getPrevUser(orgHash, owners[4]), owners[3]);
        assertEq(keyperModule.getPrevUser(orgHash, address(0)), owners[4]);
        // SENTINEL_WALLETS
        assertEq(keyperModule.getPrevUser(orgHash, owners[0]), address(0x1));
        vm.stopPrank();
    }

    function testEnableAllowlist() public {
        vm.startPrank(org1);
        keyperModule.enableAllowlist();
        assertEq(keyperModule.allowFeature(orgHash), true);
        assertEq(keyperModule.denyFeature(orgHash), false);
        vm.stopPrank();
    }

    function testEnableDenylist() public {
        vm.startPrank(org1);
        keyperModule.enableDenylist();
        assertEq(keyperModule.allowFeature(orgHash), false);
        assertEq(keyperModule.denyFeature(orgHash), true);
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
