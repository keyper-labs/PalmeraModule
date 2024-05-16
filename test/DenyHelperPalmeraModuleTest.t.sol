// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./helpers/DeployHelper.t.sol";

/// @title DenyHelperPalmeraModuleTest
/// @author
/// @notice
contract DenyHelperPalmeraModuleTest is DeployHelper {
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
        (RootOrgId, squadIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);
        org1 = palmeraModule.getSquadSafeAddress(RootOrgId);
        squadA = palmeraModule.getSquadSafeAddress(squadIdA1);
        vm.label(org1, "Org 1");
        vm.label(squadA, "SquadA");
    }

    /// @notice Test if the contract is able to add a list of owners to the allowlist
    function testAddToList() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableAllowlist();
        palmeraModule.addToList(owners);
        assertEq(palmeraModule.listCount(orgHash), owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(palmeraModule.isListed(orgHash, owners[i]), true);
        }
    }

    /// @notice Test Reverted Expected if the contract any DenyHelper actions with not Safe Wallet
    function testRevertInvalidSafe() public {
        listOfOwners();
        // EAO Address (Not Safe)
        vm.startPrank(owners[0]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, owners[0])
        );
        palmeraModule.dropFromList(owners[2]);
        vm.stopPrank();
        // Zero Address
        address ZeroAddress = address(0);
        vm.startPrank(ZeroAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, ZeroAddress)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.stopPrank();
        // Sentinal Address
        address SentinalAddress = address(0x1);
        vm.startPrank(SentinalAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, SentinalAddress)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if the contract any DenyHelper actions when the Caller is not a Root Safe
    function testRevertInvalidRootSafe() public {
        listOfOwners();
        vm.startPrank(squadA);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA)
        );
        palmeraModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if the contract any DenyHelper actions when the Caller is Another Safe not registered into the Organization
    function testRevertIfCallAnotherSafeNotRegistered() public {
        listOfOwners();
        address anotherWallet = safeHelper.setupSeveralSafeEnv(30);
        vm.startPrank(anotherWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.enableAllowlist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.enableDenylist();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.addToList(owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.dropFromList(owners[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, anotherWallet
            )
        );
        palmeraModule.dropFromList(owners[2]);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if the contract any DenyHelper actions when the DenyHelpers are disabled
    function testRevertIfDenyHelpersDisabled() public {
        listOfOwners();
        vm.startPrank(org1);
        vm.expectRevert(Errors.DenyHelpersDisabled.selector);
        palmeraModule.addToList(owners);
        address dropOwner = owners[1];
        vm.expectRevert(Errors.DenyHelpersDisabled.selector);
        palmeraModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to drop an owner from the list when the list is Empty, and Enable Allowlist
    function testRevertIfListEmptyForAllowList() public {
        listOfOwners();
        vm.startPrank(org1);
        address dropOwner = owners[1];
        palmeraModule.enableAllowlist();
        vm.expectRevert(Errors.ListEmpty.selector);
        palmeraModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to drop an owner from the list when the list is Empty, and Enable Denylist
    function testRevertIfListEmptyForDenyList() public {
        listOfOwners();
        vm.startPrank(org1);
        address dropOwner = owners[1];
        palmeraModule.enableDenylist();
        vm.expectRevert(Errors.ListEmpty.selector);
        palmeraModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to drop an owner that not exists on the list, and Enable Allowlist
    function testRevertIfInvalidAddressProvidedForAllowList() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableAllowlist();
        palmeraModule.addToList(owners);
        address dropOwner = address(0xFFF111);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to drop an owner that not exists on the list, and Enable Allowlist
    function testRevertIfInvalidAddressProvidedForDenyList() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        palmeraModule.addToList(owners);
        address dropOwner = address(0xFFF111);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.dropFromList(dropOwner);
        vm.stopPrank();
    }

    /// @notice Test if After Add to List the Length is Correct
    function testIfAfterAddtoListtheLengthisCorrect() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableAllowlist();
        palmeraModule.addToList(owners);
        assertEq(palmeraModule.listCount(orgHash), owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(palmeraModule.isListed(orgHash, owners[i]), true);
        }
    }

    /// @notice Test Reverted Expected if try to add a Zero Address to the list
    function testRevertAddToListZeroAddress() public {
        address[] memory voidOwnersArray = new address[](0);
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        palmeraModule.addToList(voidOwnersArray);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to add an Invalid Address to the list
    function testRevertAddToListInvalidAddress() public {
        listOfInvalidOwners();
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.addToList(owners);
        vm.stopPrank();
    }

    /// @notice Test Reverted Expected if try to add an Address that already exists on the list
    function testRevertAddToDuplicateAddress() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        palmeraModule.addToList(owners);

        address[] memory newOwner = new address[](1);
        newOwner[0] = address(0xDDD);

        vm.expectRevert(Errors.UserAlreadyOnList.selector);
        palmeraModule.addToList(newOwner);
        vm.stopPrank();
    }

    /// @notice Test Several Scenarios to Drop an Owner from the List
    function testDropFromList() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        palmeraModule.addToList(owners);

        // Must be Revert if drop not address (0)
        address newOwner = address(0x0);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.dropFromList(newOwner);

        // Must be the address(0xCCC)
        address ownerToRemove = owners[2];

        palmeraModule.dropFromList(ownerToRemove);
        assertEq(palmeraModule.isListed(orgHash, ownerToRemove), false);

        // Must be the address(0xEEE)
        address secOwnerToRemove = owners[4];

        palmeraModule.dropFromList(secOwnerToRemove);
        assertEq(palmeraModule.isListed(orgHash, secOwnerToRemove), false);
        vm.stopPrank();
    }

    /// @notice Test get Prev User List
    function testGetPrevUserList() public {
        listOfOwners();
        vm.startPrank(org1);
        palmeraModule.enableAllowlist();
        palmeraModule.addToList(owners);
        assertEq(palmeraModule.getPrevUser(orgHash, owners[1]), owners[0]);
        assertEq(palmeraModule.getPrevUser(orgHash, owners[2]), owners[1]);
        assertEq(palmeraModule.getPrevUser(orgHash, owners[3]), owners[2]);
        assertEq(palmeraModule.getPrevUser(orgHash, owners[4]), owners[3]);
        assertEq(palmeraModule.getPrevUser(orgHash, address(0)), owners[4]);
        // SENTINEL_WALLETS
        assertEq(palmeraModule.getPrevUser(orgHash, owners[0]), address(0x1));
        vm.stopPrank();
    }

    /// @notice Test Enable Allowlist
    function testEnableAllowlist() public {
        vm.startPrank(org1);
        palmeraModule.enableAllowlist();
        assertEq(palmeraModule.allowFeature(orgHash), true);
        assertEq(palmeraModule.denyFeature(orgHash), false);
        vm.stopPrank();
    }

    /// @notice Test Enable Denylist
    function testEnableDenylist() public {
        vm.startPrank(org1);
        palmeraModule.enableDenylist();
        assertEq(palmeraModule.allowFeature(orgHash), false);
        assertEq(palmeraModule.denyFeature(orgHash), true);
        vm.stopPrank();
    }

    /// auxiliar function to set a list of owners
    function listOfOwners() internal {
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0xDDD);
        owners[4] = address(0xEEE);
    }

    ///@notice On this function we are able to set an invalid address within some array position
    ///@dev Tested with the address(0), SENTINEL_WALLETS and address(this) on different positions
    function listOfInvalidOwners() internal {
        owners[0] = address(0xAAA);
        owners[1] = address(0xBBB);
        owners[2] = address(0xCCC);
        owners[3] = address(0x1);
        owners[4] = address(0xEEE);
    }
}
