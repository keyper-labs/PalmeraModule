// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

/// @title KeyperGuardTest
/// @custom:security-contact general@palmeradao.xyz
contract KeyperGuardTest is DeployHelper, SigningUtils {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    /// @notice Test to check if the guard is disabled
    function testDisableKeyperGuard() public {
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
    function testDisableKeyperModule() public {
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Check guard is disabled
        bool result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, safeAddr);
        assertEq(result, true);
        // Verify module has been disabled
        isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
    }

    /// @notice Test Cannot Replay Attack Test to Remove Squad
    function testCannotReplayAttackRemoveSquad() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSquadTx(squadA1Id);
        assertEq(result, true);
        // Replay attack
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.SquadAlreadyRemoved.selector);
        keyperModule.removeSquad(squadA1Id);
        vm.stopPrank();
    }

    /// @notice Test Cannot Replay Attack Test to Disconnect Safe
    function testCannotReplayAttackDisconnectedSafe() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(squadA1Id);
        assertEq(result, true);
        // Replay attack
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SquadNotRegistered.selector, squadA1Id
            )
        );
        keyperModule.disconnectSafe(squadA1Id);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SUPER_SAFE, Name -> SquadA, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafe_As_ROOTSAFE_TARGET_SUPERSAFE_SAME_TREE()
        public
    {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(squadIdA1);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        safeHelper.updateSafeInterface(squadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(squadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SQUAD_SAFE, Name -> SubSquadA, Hierarchy related to caller -> SAME_TREE
    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ROOTSAFE_SAME_TREE()
        public
    {
        (uint256 rootId,, uint256 subSquadA1Id,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Disconnect Safe
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(subSquadA1Id);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        safeHelper.updateSafeInterface(subSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
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
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        safeHelper.updateSafeInterface(rootAddr);

        /// Disconnect Safe
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotRemoveSquadBeforeRemoveChild.selector, 1
            )
        );
        keyperModule.disconnectSafe(rootId);
        vm.stopPrank();

        /// Verify Safe still enabled
        /// Verify module still enabled
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        /// Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> N/A
    function testDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Not_Have_children()
        public
    {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSquadTx(squadA1Id);
        assertEq(result, true);

        safeHelper.createRemoveSquadTx(rootId);
        assertEq(result, true);

        /// Disconnect Safe
        result = safeHelper.createDisconnectSafeTx(rootId);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        /// Verify guard has been removed
        address ZeroAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> squadA
    // Target Info: Type-> SAFE, Name -> subSquadA, Hierarchy related to caller -> SAME_TREE
    function testCannotDisconnectSafe_As_SuperSafe_As_SameTree() public {
        (, uint256 squadIdA1, uint256 subSquadA1Id,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Remove Squad A1
        safeHelper.updateSafeInterface(squadA1Addr);
        bool result = safeHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadA1Addr)
        );
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> squadA
    // Target Info: Type-> SAFE, Name -> subSquadA, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannotDisconnectSafe_As_SuperSafe_As_DifferentTree() public {
        (, uint256 squadIdA1,, uint256 squadIdB1, uint256 subSquadA1Id,) =
        keyperSafeBuilder.setupTwoOrgWithOneRootOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);
        address squadB1Addr = keyperModule.getSquadSafeAddress(squadIdB1);

        // Remove Squad A1
        safeHelper.updateSafeInterface(squadA1Addr);
        bool result = safeHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(squadB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRootSafe.selector, squadB1Addr)
        );
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Squad, Name -> rootB
    // Target Info: Type-> SQUAD_SAFE, Name -> subSquadA1Id, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannotDisconnectSafe_As_RootSafe_As_DifferentTree() public {
        (uint256 rootIdA,, uint256 rootIdB,, uint256 subSquadA1Id,) =
        keyperSafeBuilder.setupTwoOrgWithOneRootOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);

        // Remove Squad A1
        safeHelper.updateSafeInterface(rootAddrA);
        bool result = safeHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedDisconnectChildrenSquad.selector);
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        safeHelper.updateSafeInterface(subSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SAFE, Name -> squadA1Id, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafeBeforeToRemoveSquad_One_Level() public {
        (uint256 rootId, uint256 squadIdA1,,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Disconnect Safe before to remove squad
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(squadIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        safeHelper.updateSafeInterface(squadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(squadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> subSquadIdA1, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafeBeforeToRemoveSquad_Two_Level() public {
        (uint256 rootId,, uint256 subSquadIdA1,) = keyperSafeBuilder
            .setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadIdA1);

        // Try to Disconnect Safe before to remove squad
        // Disconnect Safe before to remove squad
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createDisconnectSafeTx(subSquadIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        safeHelper.updateSafeInterface(subSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // Caller Info: Role-> EOA, Type -> SAFE, Hierarchy -> SAFE_LEAD, Name -> fakerCaller
    // Target Info: Type-> SQUAD_SAFE, Name -> childSquadA1, Hierarchy related to caller -> N/A
    function testCannotDisconnectSafe_As_SafeLead_As_EOA() public {
        (uint256 rootId,, uint256 childSquadA1,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = address(0xCBA);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove squad
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidSafe.selector, fakerCaller)
        );
        keyperModule.disconnectSafe(childSquadA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE, Type -> SAFE, Hierarchy -> SAFE_LEAD, Name -> fakerCaller
    // Target Info: Type-> SQUAD_SAFE, Name -> childSquadA1, Hierarchy related to caller -> N/A
    function testCannotDisconnectSafe_As_SafeLead_As_SAFE() public {
        (uint256 rootId,, uint256 childSquadA1,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = safeHelper.newKeyperSafe(3, 1);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove squad
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, fakerCaller
            )
        );
        keyperModule.disconnectSafe(childSquadA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> squadIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisableKeyperModuleIfGuardEnabled() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Try to disable Module from root
        safeHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        bool result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, rootAddr);
        assertEq(result, false);

        // Verify module is still enabled
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);

        // Try to disable Module from squad
        safeHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, squadA1Addr);
        assertEq(result, false);

        // Verify module is still enabled
        isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> squadIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisableKeyperModuleAfterRemoveSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSquadTx(squadIdA1);
        assertEq(result, true);

        // Try to disable Guard from Squad Removed
        safeHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, squadA1Addr);
        assertEq(result, false);

        // Verify module still enabled
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> squadIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisableKeyperGuardIfGuardEnabled() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Try to disable Guard from root
        safeHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
            )
        );
        bool result = safeHelper.disableGuardTx(rootAddr);
        assertEq(result, false);

        // Verify Guard is still enabled
        address keyperGuardAddrTest = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(keyperGuardAddrTest, keyperGuardAddr);

        // Try to disable Guard from squad
        safeHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
            )
        );
        result = safeHelper.disableGuardTx(squadA1Addr);
        assertEq(result, false);

        // Verify Guard is still enabled
        keyperGuardAddrTest = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(keyperGuardAddrTest, keyperGuardAddr);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> squadIdA1, Hierarchy related to caller -> SAME_TREE
    function testCannotDisableKeyperGuardAfterRemoveSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        // Remove Squad A1
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveSquadTx(squadIdA1);
        assertEq(result, true);

        // Try to disable Guard from Squad Removed
        safeHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result =
            safeHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, squadA1Addr);
        assertEq(result, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
            )
        );
        result = safeHelper.disableGuardTx(squadA1Addr);
        assertEq(result, false);

        // Verify Guard still enabled
        address GuardAddress = abi.decode(
            StorageAccessible(address(safeHelper.safeWallet())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(GuardAddress, address(keyperGuard)); // If Guard is disabled, the address storage will be ZeroAddress (0x0)
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootId
    // Target Info: Type-> SQUAD_SAFE, Name -> childSquadA1, Hierarchy related to caller -> SAME_TREE
    function testDisconnectSafe_As_ROOTSAFE_TARGET_ROOT_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1,,) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        /// Remove Squad A1
        safeHelper.updateSafeInterface(squadA1Addr);
        bool result = safeHelper.createRemoveSquadTx(childSquadA1);
        assertEq(result, true);

        /// Disconnect Safe
        safeHelper.updateSafeInterface(rootAddr);
        result = safeHelper.createDisconnectSafeTx(childSquadA1);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        safeHelper.updateSafeInterface(childSquadA1Addr);
        bool isKeyperModuleEnabled =
            safeHelper.safeWallet().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        /// Verify guard has been removed
        address ZeroAddress = abi.decode(
            StorageAccessible(childSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    // ! **************** List of Promote to Root *******************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SQUAD_SAFE, Name -> childSquadA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SQUAD_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1,,) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        /// Promote to Root
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonSuperSafe.selector);
        keyperModule.promoteRoot(childSquadA1);
        vm.stopPrank();

        /// Verify child Safe is not an Root
        assertEq(keyperModule.getRootSafe(childSquadA1) == rootId, true);
        assertEq(keyperModule.getRootSafe(childSquadA1) == childSquadA1, false);
        assertEq(keyperModule.isRootSafeOf(childSquadA1Addr, rootId), false);
        assertEq(keyperModule.isRootSafeOf(rootAddr, childSquadA1), true);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, childSquadA1), false);
        assertEq(keyperModule.isSuperSafe(rootId, squadA1Id), true);
        assertEq(keyperModule.isSuperSafe(squadA1Id, childSquadA1), true);
        assertEq(keyperModule.isTreeMember(rootId, squadA1Id), true);
        assertEq(keyperModule.isTreeMember(squadA1Id, childSquadA1), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> SUPER_SAFE, Name -> squadA1, Hierarchy related to caller -> SAME_TREE
    function testCanPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1,,) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        /// Promote to Root
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createPromoteToRootTx(squadA1Id);
        assertEq(result, true);

        /// Verify Safe has been promoted to Root
        assertEq(keyperModule.getRootSafe(squadA1Id) == rootId, false);
        assertEq(keyperModule.getRootSafe(squadA1Id) == squadA1Id, true);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, rootId), false);
        assertEq(keyperModule.isRootSafeOf(rootAddr, squadA1Id), false);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, squadA1Id), true);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, childSquadA1), true);
        assertEq(keyperModule.isSuperSafe(rootId, squadA1Id), false);
        assertEq(keyperModule.isSuperSafe(squadA1Id, childSquadA1), true);
        assertEq(keyperModule.isTreeMember(rootId, squadA1Id), false);
        assertEq(keyperModule.isTreeMember(squadA1Id, childSquadA1), true);

        // Validate Info Safe Squad
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getSquadInfo(squadA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.ROOT));
        assertEq(name, squadA1Name);
        assertEq(lead, address(0));
        assertEq(safe, squadA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], childSquadA1);
        assertEq(superSafe, 0);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootB
    // Target Info: Type-> SUPER_SAFE, Name -> squadA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE_ANOTHER_TREE(
    ) public {
        (
            uint256 rootIdA,
            uint256 squadA1Id,
            uint256 rootIdB,
            ,
            uint256 childSquadA1,
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            org2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        /// Try Promote to Root
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSquad.selector);
        keyperModule.promoteRoot(squadA1Id);
        vm.stopPrank();

        /// Verify SuperSafe is not an Root
        assertEq(keyperModule.getRootSafe(squadA1Id) == rootIdA, true);
        assertEq(keyperModule.getRootSafe(squadA1Id) == childSquadA1, false);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, rootIdA), false);
        assertEq(keyperModule.isRootSafeOf(rootAddrA, squadA1Id), true);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, childSquadA1), false);
        assertEq(keyperModule.isSuperSafe(rootIdA, squadA1Id), true);
        assertEq(keyperModule.isSuperSafe(squadA1Id, childSquadA1), true);
        assertEq(keyperModule.isTreeMember(rootIdA, squadA1Id), true);
        assertEq(keyperModule.isTreeMember(squadA1Id, childSquadA1), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootB
    // Target Info: Type-> SUPER_SAFE, Name -> squadA1, Hierarchy related to caller -> SAME_TREE
    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE_ANOTHER_ORG()
        public
    {
        (
            uint256 rootIdA,
            uint256 squadA1Id,
            uint256 rootIdB,
            ,
            uint256 childSquadA1,
        ) = keyperSafeBuilder.setupTwoOrgWithOneRootOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            org2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        /// Try Promote to Root
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenSquad.selector);
        keyperModule.promoteRoot(squadA1Id);
        vm.stopPrank();

        /// Verify SuperSafe is not an Root
        assertEq(keyperModule.getRootSafe(squadA1Id) == rootIdA, true);
        assertEq(keyperModule.getRootSafe(squadA1Id) == childSquadA1, false);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, rootIdA), false);
        assertEq(keyperModule.isRootSafeOf(rootAddrA, squadA1Id), true);
        assertEq(keyperModule.isRootSafeOf(squadA1Addr, childSquadA1), false);
        assertEq(keyperModule.isSuperSafe(rootIdA, squadA1Id), true);
        assertEq(keyperModule.isSuperSafe(squadA1Id, childSquadA1), true);
        assertEq(keyperModule.isTreeMember(rootIdA, squadA1Id), true);
        assertEq(keyperModule.isTreeMember(squadA1Id, childSquadA1), true);
    }

    // ! **************** List of Remove Whole Tree *******************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root1,root2
    // Target Info: Type-> ROOT_SAFE, Name -> root1,root2 Hierarchy related to caller -> SAME_TREE
    function testCanRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 squadA1Id,
            uint256 rootId2,
            uint256 squadB1Id,
            uint256 childSquadA1,
            uint256 childSquadB1
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            org2Name,
            squadBName,
            subSquadA1Name,
            subSquadB1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address rootAddr2 = keyperModule.getSquadSafeAddress(rootId2);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address squadB1Addr = keyperModule.getSquadSafeAddress(squadB1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);
        address childSquadB1Addr =
            keyperModule.getSquadSafeAddress(childSquadB1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Whole Tree A is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr), false);
        assertEq(keyperModule.isSafeRegistered(squadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadA1Addr), false);
        assertTrue(keyperModule.isSafeRegistered(rootAddr2));
        assertTrue(keyperModule.isSafeRegistered(squadB1Addr));
        assertTrue(keyperModule.isSafeRegistered(childSquadB1Addr));

        /// Remove Whole Tree B
        safeHelper.updateSafeInterface(rootAddr2);
        result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Tree is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr2), false);
        assertEq(keyperModule.isSafeRegistered(squadB1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadB1Addr), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> SAME_TREE
    function testCanRemoveWholeTreeFourthLevel() public {
        (
            uint256 rootId,
            uint256 squadA1Id,
            uint256 squadB1Id,
            uint256 childSquadA1,
            uint256 subChildSquadA1
        ) = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSquadB1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address squadB1Addr = keyperModule.getSquadSafeAddress(squadB1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);
        address subChildSquadB1Addr =
            keyperModule.getSquadSafeAddress(subChildSquadA1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Whole Tree A is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr), false);
        assertEq(keyperModule.isSafeRegistered(squadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(subChildSquadB1Addr), false);
        assertEq(keyperModule.isSafeRegistered(squadB1Addr), false);

        // Validate Info Root Safe Squad
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SquadNotRegistered.selector, rootId)
        );
        keyperModule.getSquadInfo(rootId);
        vm.stopPrank();
        // Validate Info Root Safe Squad
        vm.startPrank(subChildSquadB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SquadNotRegistered.selector, subChildSquadA1
            )
        );
        keyperModule.getSquadInfo(subChildSquadA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> root
    // Target Info: Type-> ROOT_SAFE, Name -> root, Hierarchy related to caller -> SAME_TREE
    function testCannotReplayAttackRemoveWholeTree() public {
        (
            uint256 rootId,
            uint256 squadA1Id,
            uint256 squadB1Id,
            uint256 childSquadA1,
            uint256 subChildSquadA1
        ) = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSquadB1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address squadB1Addr = keyperModule.getSquadSafeAddress(squadB1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);
        address subChildSquadB1Addr =
            keyperModule.getSquadSafeAddress(subChildSquadA1);

        /// Remove Whole Tree A
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        // Try Replay Attack
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SafeNotRegistered.selector, rootAddr)
        );
        keyperModule.removeWholeTree();
        vm.stopPrank();

        /// Verify Whole Tree A is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr), false);
        assertEq(keyperModule.isSafeRegistered(squadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(subChildSquadB1Addr), false);
        assertEq(keyperModule.isSafeRegistered(squadB1Addr), false);
    }
}
