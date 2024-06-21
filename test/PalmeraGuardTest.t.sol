// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title PalmeraGuardTest
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraGuardTest is DeployHelper, SigningUtils {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    /// @notice Test to check if the guard is disabled
    function testDisablePalmeraGuard() public {
        // Check guard is disabled
        bool result = safeHelper.disableGuardTx(safeAddr);
        assertEq(result, true);
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(safeAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    /// @notice Test to check if the module is disabled
    function testDisablePalmeraModule() public {
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Check guard is disabled
        bool result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeAddr);
        assertEq(result, true);
        // Verify module has been disabled
        isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
    }

    /// @notice Test Cannot Replay Attack Test to Remove Safe
    function testCannotReplayAttackRemoveSafe() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        /// Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(safeA1Id);
        assertEq(result, true);
        // Replay attack
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.SafeAlreadyRemoved.selector);
        palmeraModule.removeSafe(safeA1Id);
        vm.stopPrank();
    }

    /// @notice Test Cannot Replay Attack Test to Disconnect Safe
    function testCannotReplayAttackDisconnectedSafe() public {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        /// Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(safeA1Id);
        assertEq(result, true);
        // Replay attack
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeIdNotRegistered.selector, safeA1Id
            )
        );
        palmeraModule.disconnectSafe(safeA1Id);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SUPER_SAFE, Name -> SafeA, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafe_As_ROOTSAFE_TARGET_SUPERSAFE_SAME_TREE()
        public
    {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        // Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(safeIdA1);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        safeHelper.updateSafeInterface(safeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(safeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> safe_SAFE, Name -> SubSafeA, Hierarchy related to caller -> SAME_TREE
    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ROOTSAFE_SAME_TREE()
        public
    {
        (uint256 rootId,, uint256 subSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);

        // Disconnect Safe
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(subSafeA1Id);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        safeHelper.updateSafeInterface(subSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> N/A
    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Have_children(
    ) public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        safeHelper.updateSafeInterface(rootAddr);

        /// Disconnect Safe
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotRemoveSafeBeforeRemoveChild.selector, 1
            )
        );
        palmeraModule.disconnectSafe(rootId);
        vm.stopPrank();

        /// Verify Safe still enabled
        /// Verify module still enabled
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
        /// Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(palmeraGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> N/A
    function testDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Not_Have_children()
        public
    {
        (uint256 rootId, uint256 safeA1Id) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        /// Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(safeA1Id);
        assertEq(result, true);

        safeHelper.createRemoveSafeTx(rootId);
        assertEq(result, true);

        /// Disconnect Safe
        result = safeHelper.createDisconnectSafeTx(rootId);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        /// Verify guard has been removed
        address ZeroAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA
    // Target Info: Type-> SAFE, Name -> subSafeA, Hierarchy related to caller -> SAME_TREE
    function testCannotDisconnectSafe_As_SuperSafe_As_SameTree() public {
        (, uint256 safeIdA1, uint256 subSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);

        // Remove Safe A1
        safeHelper.updateSafeInterface(safeA1Addr);
        bool result = safeHelper.createRemoveSafeTx(subSafeA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, safeA1Addr)
        );
        palmeraModule.disconnectSafe(subSafeA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(palmeraGuard));
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> safeA
    // Target Info: Type-> SAFE, Name -> subSafeA, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannotDisconnectSafe_As_SuperSafe_As_DifferentTree() public {
        (, uint256 safeIdA1,, uint256 safeIdB1, uint256 subSafeA1Id,) =
        palmeraSafeBuilder.setupTwoOrgWithOneRootOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);
        address safeB1Addr = palmeraModule.getSafeAddress(safeIdB1);

        // Remove Safe A1
        safeHelper.updateSafeInterface(safeA1Addr);
        bool result = safeHelper.createRemoveSafeTx(subSafeA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(safeB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, safeB1Addr)
        );
        palmeraModule.disconnectSafe(subSafeA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(palmeraGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Safe, Name -> rootB
    // Target Info: Type-> safe_SAFE, Name -> subSafeA1Id, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannotDisconnectSafe_As_RootSafe_As_DifferentTree() public {
        (uint256 rootIdA,, uint256 rootIdB,, uint256 subSafeA1Id,) =
        palmeraSafeBuilder.setupTwoOrgWithOneRootOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeA1Id);
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);

        // Remove Safe A1
        safeHelper.updateSafeInterface(rootAddrA);
        bool result = safeHelper.createRemoveSafeTx(subSafeA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedDisconnectChildrenSafe.selector);
        palmeraModule.disconnectSafe(subSafeA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(palmeraGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SAFE, Name -> safeA1Id, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafeBeforeToRemoveSafe_One_Level() public {
        (uint256 rootId, uint256 safeIdA1,,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        // Disconnect Safe before to remove safe
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(safeIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        safeHelper.updateSafeInterface(safeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(safeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> subSafeIdA1, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafeBeforeToRemoveSafe_Two_Level() public {
        (uint256 rootId,, uint256 subSafeIdA1,) = palmeraSafeBuilder
            .setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address subSafeA1Addr = palmeraModule.getSafeAddress(subSafeIdA1);

        // Try to Disconnect Safe before to remove safe
        // Disconnect Safe before to remove safe
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(subSafeIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        safeHelper.updateSafeInterface(subSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> EOA, Type -> SAFE, Hierarchy -> SAFE_LEAD, Name -> fakerCaller
    // Target Info: Type-> safe_SAFE, Name -> childSafeA1, Hierarchy related to caller -> N/A
    function testCannotDisconnectSafe_As_SafeLead_As_EOA() public {
        (uint256 rootId,, uint256 childSafeA1,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);

        // Send ETH to safe&subsafe
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSafeA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = address(0xCBA);

        // Set Safe Role in Safe A1 over Child Safe A1
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childSafeA1,
            true
        );
        assertTrue(palmeraModule.isSafeLead(childSafeA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove safe
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, fakerCaller)
        );
        palmeraModule.disconnectSafe(childSafeA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE, Type -> SAFE, Hierarchy -> SAFE_LEAD, Name -> fakerCaller
    // Target Info: Type-> safe_SAFE, Name -> childSafeA1, Hierarchy related to caller -> N/A
    function testCannotDisconnectSafe_As_SafeLead_As_SAFE() public {
        (uint256 rootId,, uint256 childSafeA1,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);

        // Send ETH to safe&subsafe
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSafeA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = safeHelper.newPalmeraSafe(3, 1);

        // Set Safe Role in Safe A1 over Child Safe A1
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childSafeA1,
            true
        );
        assertTrue(palmeraModule.isSafeLead(childSafeA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove safe
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, fakerCaller
            )
        );
        palmeraModule.disconnectSafe(childSafeA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> safeIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisablePalmeraModuleIfGuardEnabled() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        // Try to disable Module from root
        safeHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(palmeraModule)
            )
        );
        bool result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, rootAddr);
        assertEq(result, false);

        // Verify module is still enabled
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);

        // Try to disable Module from safe
        safeHelper.updateSafeInterface(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(palmeraModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeA1Addr);
        assertEq(result, false);

        // Verify module is still enabled
        isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> safeIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisablePalmeraModuleAfterRemoveSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        // Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(safeIdA1);
        assertEq(result, true);

        // Try to disable Guard from Safe Removed
        safeHelper.updateSafeInterface(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(palmeraModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeA1Addr);
        assertEq(result, false);

        // Verify module still enabled
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> safeIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisablePalmeraGuardIfGuardEnabled() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        // Try to disable Guard from root
        safeHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(palmeraGuard)
            )
        );
        bool result = safeHelper.disableGuardTx(rootAddr);
        assertEq(result, false);

        // Verify Guard is still enabled
        address palmeraGuardAddrTest = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(palmeraGuardAddrTest, palmeraGuardAddr);

        // Try to disable Guard from safe
        safeHelper.updateSafeInterface(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(palmeraGuard)
            )
        );
        result = safeHelper.disableGuardTx(safeA1Addr);
        assertEq(result, false);

        // Verify Guard is still enabled
        palmeraGuardAddrTest = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(palmeraGuardAddrTest, palmeraGuardAddr);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> safeIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisablePalmeraGuardAfterRemoveSafe() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        // Remove Safe A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSafeTx(safeIdA1);
        assertEq(result, true);

        // Try to disable Guard from Safe Removed
        safeHelper.updateSafeInterface(safeA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(palmeraModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeA1Addr);
        assertEq(result, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(palmeraGuard)
            )
        );
        result = safeHelper.disableGuardTx(safeA1Addr);
        assertEq(result, false);

        // Verify Guard still enabled
        address GuardAddress = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(GuardAddress, address(palmeraGuard)); // If Guard is disabled, the address storage will be ZeroAddress (0x0)
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> safe_SAFE, Name -> childSafeA1, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafe_As_ROOTSAFE_TARGET_ROOT_SAFE() public {
        (uint256 rootId, uint256 safeA1Id, uint256 childSafeA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);

        /// Remove Safe A1
        safeHelper.updateSafeInterface(safeA1Addr);
        bool result = safeHelper.createRemoveSafeTx(childSafeA1);
        assertEq(result, true);

        /// Disconnect Safe
        safeHelper.updateSafeInterface(rootAddr);
        result = safeHelper.createDisconnectSafeTx(childSafeA1);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        safeHelper.updateSafeInterface(childSafeA1Addr);
        bool isPalmeraModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(palmeraModule));
        assertEq(isPalmeraModuleEnabled, false);
        /// Verify guard has been removed
        address ZeroAddress = abi.decode(
            StorageAccessible(childSafeA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // ! **************** List of Promote to Root *******************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> safe_SAFE, Name -> childSafeA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_safe_SAFE() public {
        (uint256 rootId, uint256 safeA1Id, uint256 childSafeA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);

        /// Promote to Root
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonSuperSafe.selector);
        palmeraModule.promoteRoot(childSafeA1);
        vm.stopPrank();

        /// Verify child Safe is not an Root
        assertEq(palmeraModule.getRootSafe(childSafeA1) == rootId, true);
        assertEq(palmeraModule.getRootSafe(childSafeA1) == childSafeA1, false);
        assertEq(palmeraModule.isRootSafeOf(childSafeA1Addr, rootId), false);
        assertEq(palmeraModule.isRootSafeOf(rootAddr, childSafeA1), true);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, childSafeA1), false);
        assertEq(palmeraModule.isSuperSafe(rootId, safeA1Id), true);
        assertEq(palmeraModule.isSuperSafe(safeA1Id, childSafeA1), true);
        assertEq(palmeraModule.isTreeMember(rootId, safeA1Id), true);
        assertEq(palmeraModule.isTreeMember(safeA1Id, childSafeA1), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SUPER_SAFE, Name -> safeA1, Hierarchy related to caller -> SAME_TREE
    function testCanPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE() public {
        (uint256 rootId, uint256 safeA1Id, uint256 childSafeA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);

        /// Promote to Root
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createPromoteToRootTx(safeA1Id);
        assertEq(result, true);

        /// Verify Safe has been promoted to Root
        assertEq(palmeraModule.getRootSafe(safeA1Id) == rootId, false);
        assertEq(palmeraModule.getRootSafe(safeA1Id) == safeA1Id, true);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, rootId), false);
        assertEq(palmeraModule.isRootSafeOf(rootAddr, safeA1Id), false);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, safeA1Id), true);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, childSafeA1), true);
        assertEq(palmeraModule.isSuperSafe(rootId, safeA1Id), false);
        assertEq(palmeraModule.isSuperSafe(safeA1Id, childSafeA1), true);
        assertEq(palmeraModule.isTreeMember(rootId, safeA1Id), false);
        assertEq(palmeraModule.isTreeMember(safeA1Id, childSafeA1), true);

        // Validate Info Safe
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafeId
        ) = palmeraModule.getSafeInfo(safeA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.ROOT));
        assertEq(name, safeA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], childSafeA1);
        assertEq(superSafeId, 0);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootB
    // Target Info: Type-> SUPER_SAFE, Name -> safeA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE_ANOTHER_TREE(
    ) public {
        (
            uint256 rootIdA,
            uint256 safeA1Id,
            uint256 rootIdB,
            ,
            uint256 childSafeA1,
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);

        /// Try Promote to Root
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSafe.selector);
        palmeraModule.promoteRoot(safeA1Id);
        vm.stopPrank();

        /// Verify SuperSafe is not an Root
        assertEq(palmeraModule.getRootSafe(safeA1Id) == rootIdA, true);
        assertEq(palmeraModule.getRootSafe(safeA1Id) == childSafeA1, false);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, rootIdA), false);
        assertEq(palmeraModule.isRootSafeOf(rootAddrA, safeA1Id), true);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, childSafeA1), false);
        assertEq(palmeraModule.isSuperSafe(rootIdA, safeA1Id), true);
        assertEq(palmeraModule.isSuperSafe(safeA1Id, childSafeA1), true);
        assertEq(palmeraModule.isTreeMember(rootIdA, safeA1Id), true);
        assertEq(palmeraModule.isTreeMember(safeA1Id, childSafeA1), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootB
    // Target Info: Type-> SUPER_SAFE, Name -> safeA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE_ANOTHER_ORG()
        public
    {
        (
            uint256 rootIdA,
            uint256 safeA1Id,
            uint256 rootIdB,
            ,
            uint256 childSafeA1,
        ) = palmeraSafeBuilder.setupTwoOrgWithOneRootOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);

        /// Try Promote to Root
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSafe.selector);
        palmeraModule.promoteRoot(safeA1Id);
        vm.stopPrank();

        /// Verify SuperSafe is not an Root
        assertEq(palmeraModule.getRootSafe(safeA1Id) == rootIdA, true);
        assertEq(palmeraModule.getRootSafe(safeA1Id) == childSafeA1, false);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, rootIdA), false);
        assertEq(palmeraModule.isRootSafeOf(rootAddrA, safeA1Id), true);
        assertEq(palmeraModule.isRootSafeOf(safeA1Addr, childSafeA1), false);
        assertEq(palmeraModule.isSuperSafe(rootIdA, safeA1Id), true);
        assertEq(palmeraModule.isSuperSafe(safeA1Id, childSafeA1), true);
        assertEq(palmeraModule.isTreeMember(rootIdA, safeA1Id), true);
        assertEq(palmeraModule.isTreeMember(safeA1Id, childSafeA1), true);
    }

    // ! **************** List of Remove Whole Tree *******************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root1,root2
    // Target Info: Type-> ROOT_SAFE, Name -> root1,root2 Hierarchy related to caller -> SAME_TREE
    function testCanRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 safeA1Id,
            uint256 rootId2,
            uint256 safeB1Id,
            uint256 childSafeA1,
            uint256 childSafeB1
        ) = palmeraSafeBuilder.setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            org2Name,
            safeBName,
            subSafeA1Name,
            subSafeB1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address rootAddr2 = palmeraModule.getSafeAddress(rootId2);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeB1Addr = palmeraModule.getSafeAddress(safeB1Id);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);
        address childSafeB1Addr = palmeraModule.getSafeAddress(childSafeB1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Whole Tree A is removed
        assertEq(palmeraModule.isSafeRegistered(rootAddr), false);
        assertEq(palmeraModule.isSafeRegistered(safeA1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(childSafeA1Addr), false);
        assertTrue(palmeraModule.isSafeRegistered(rootAddr2));
        assertTrue(palmeraModule.isSafeRegistered(safeB1Addr));
        assertTrue(palmeraModule.isSafeRegistered(childSafeB1Addr));

        /// Remove Whole Tree B
        safeHelper.updateSafeInterface(rootAddr2);
        result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Tree is removed
        assertEq(palmeraModule.isSafeRegistered(rootAddr2), false);
        assertEq(palmeraModule.isSafeRegistered(safeB1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(childSafeB1Addr), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> SAME_TREE
    function testCanRemoveWholeTreeFourthLevel() public {
        (
            uint256 rootId,
            uint256 safeA1Id,
            uint256 safeB1Id,
            uint256 childSafeA1,
            uint256 subChildSafeA1
        ) = palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, safeA1Name, safeBName, subSafeA1Name, subSafeB1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeB1Addr = palmeraModule.getSafeAddress(safeB1Id);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);
        address subChildSafeB1Addr =
            palmeraModule.getSafeAddress(subChildSafeA1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Whole Tree A is removed
        assertEq(palmeraModule.isSafeRegistered(rootAddr), false);
        assertEq(palmeraModule.isSafeRegistered(safeA1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(childSafeA1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(subChildSafeB1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(safeB1Addr), false);

        // Validate Info Root Safe
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SafeIdNotRegistered.selector, rootId)
        );
        palmeraModule.getSafeInfo(rootId);
        vm.stopPrank();
        // Validate Info Root Safe
        vm.startPrank(subChildSafeB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeIdNotRegistered.selector, subChildSafeA1
            )
        );
        palmeraModule.getSafeInfo(subChildSafeA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> SAME_TREE
    function testCannotReplayAttackRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 safeA1Id,
            uint256 safeB1Id,
            uint256 childSafeA1,
            uint256 subChildSafeA1
        ) = palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, safeA1Name, safeBName, subSafeA1Name, subSafeB1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeB1Addr = palmeraModule.getSafeAddress(safeB1Id);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);
        address subChildSafeB1Addr =
            palmeraModule.getSafeAddress(subChildSafeA1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        // Try Replay Attack
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SafeNotRegistered.selector, rootAddr)
        );
        palmeraModule.removeWholeTree();
        vm.stopPrank();

        /// Verify Whole Tree A is removed
        assertEq(palmeraModule.isSafeRegistered(rootAddr), false);
        assertEq(palmeraModule.isSafeRegistered(safeA1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(childSafeA1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(subChildSafeB1Addr), false);
        assertEq(palmeraModule.isSafeRegistered(safeB1Addr), false);
    }
}
