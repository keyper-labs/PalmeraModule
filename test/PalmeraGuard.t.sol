// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

contract PalmeraGuardTest is DeployHelper, SigningUtils {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    function testDisablePalmeraGuard() public {
        // Check guard is disabled
        bool result = gnosisHelper.disableGuardTx(gnosisSafeAddr);
        assertEq(result, true);
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, gnosisSafeAddr
        );
        assertEq(result, true);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(gnosisSafeAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testDisablePalmeraModule() public {
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Check guard is disabled
        bool result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, gnosisSafeAddr
        );
        assertEq(result, true);
        // Verify module has been disabled
        isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
    }

    function testCannotReplayAttackRemoveSquad() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(squadA1Id);
        assertEq(result, true);
        // Replay attack
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.SquadAlreadyRemoved.selector);
        keyperModule.removeSquad(squadA1Id);
        vm.stopPrank();
    }

    function testCannotReplayAttackDisconnectedSafe() public {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectSafeTx(squadA1Id);
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

    function testDisconnectSafe_As_ROOTSAFE_TARGET_SUPERSAFE_SAME_TREE()
        public
    {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectSafeTx(squadIdA1);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(squadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(squadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ROOTSAFE_SAME_TREE()
        public
    {
        (uint256 rootId,, uint256 subSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Disconnect Safe
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectSafeTx(subSquadA1Id);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(subSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Have_children(
    ) public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        gnosisHelper.updateSafeInterface(rootAddr);

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
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
        /// Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    function testDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Not_Have_children()
        public
    {
        (uint256 rootId, uint256 squadA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        /// Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(squadA1Id);
        assertEq(result, true);

        gnosisHelper.createRemoveSquadTx(rootId);
        assertEq(result, true);

        /// Disconnect Safe
        result = gnosisHelper.createDisconnectSafeTx(rootId);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
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

    function testCannotDisconnectSafe_As_SuperSafe_As_SameTree() public {
        (, uint256 squadIdA1, uint256 subSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadA1Id);

        // Remove Squad A1
        gnosisHelper.updateSafeInterface(squadA1Addr);
        bool result = gnosisHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadA1Addr
            )
        );
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

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
        gnosisHelper.updateSafeInterface(squadA1Addr);
        bool result = gnosisHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(squadB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, squadB1Addr
            )
        );
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

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
        gnosisHelper.updateSafeInterface(rootAddrA);
        bool result = gnosisHelper.createRemoveSquadTx(subSquadA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedDisconnectChildrenSquad.selector);
        keyperModule.disconnectSafe(subSquadA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    function testDisconnectSafeBeforeToRemoveSquad_One_Level() public {
        (uint256 rootId, uint256 squadIdA1,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Disconnect Safe before to remove squad
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectSafeTx(squadIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(squadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(squadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testDisconnectSafeBeforeToRemoveSquad_Two_Level() public {
        (uint256 rootId,, uint256 subSquadIdA1,) = keyperSafeBuilder
            .setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address subSquadA1Addr = keyperModule.getSquadSafeAddress(subSquadIdA1);

        // Try to Disconnect Safe before to remove squad
        // Disconnect Safe before to remove squad
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectSafeTx(subSquadIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(subSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subSquadA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_SafeLead_As_EOA() public {
        (uint256 rootId,, uint256 childSquadA1) = keyperSafeBuilder
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
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakerCaller
            )
        );
        keyperModule.disconnectSafe(childSquadA1);
        vm.stopPrank();
    }

    function testCannotDisconnectSafe_As_SafeLead_As_SAFE() public {
        (uint256 rootId,, uint256 childSquadA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = gnosisHelper.newPalmeraSafe(3, 1);

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

    function testCannotDisablePalmeraModuleIfGuardEnabled() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Try to disable Module from root
        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(keyperModule)
            )
        );
        bool result =
            gnosisHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, rootAddr);
        assertEq(result, false);

        // Verify module is still enabled
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);

        // Try to disable Module from squad
        gnosisHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, squadA1Addr
        );
        assertEq(result, false);

        // Verify module is still enabled
        isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    function testCannotDisablePalmeraModuleAfterRemoveSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(squadIdA1);
        assertEq(result, true);

        // Try to disable Guard from Squad Removed
        gnosisHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, squadA1Addr
        );
        assertEq(result, false);

        // Verify module still enabled
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, true);
    }

    function testCannotDisablePalmeraGuardIfGuardEnabled() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Try to disable Guard from root
        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(keyperGuard)
            )
        );
        bool result = gnosisHelper.disableGuardTx(rootAddr);
        assertEq(result, false);

        // Verify Guard is still enabled
        address keyperGuardAddrTest = abi.decode(
            StorageAccessible(address(gnosisHelper.gnosisSafe())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(keyperGuardAddrTest, keyperGuardAddr);

        // Try to disable Guard from squad
        gnosisHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(keyperGuard)
            )
        );
        result = gnosisHelper.disableGuardTx(squadA1Addr);
        assertEq(result, false);

        // Verify Guard is still enabled
        keyperGuardAddrTest = abi.decode(
            StorageAccessible(address(gnosisHelper.gnosisSafe())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(keyperGuardAddrTest, keyperGuardAddr);
    }

    function testCannotDisablePalmeraGuardAfterRemoveSquad() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        // Remove Squad A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveSquadTx(squadIdA1);
        assertEq(result, true);

        // Try to disable Guard from Squad Removed
        gnosisHelper.updateSafeInterface(squadA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraModule.selector,
                address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, squadA1Addr
        );
        assertEq(result, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisablePalmeraGuard.selector, address(keyperGuard)
            )
        );
        result = gnosisHelper.disableGuardTx(squadA1Addr);
        assertEq(result, false);

        // Verify Guard still enabled
        address GuardAddress = abi.decode(
            StorageAccessible(address(gnosisHelper.gnosisSafe())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(GuardAddress, address(keyperGuard)); // If disable Guard, the address storage will be ZeroAddress (0x0)
    }

    function testDisconnectSafe_As_ROOTSAFE_TARGET_ROOT_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        /// Remove Squad A1
        gnosisHelper.updateSafeInterface(squadA1Addr);
        bool result = gnosisHelper.createRemoveSquadTx(childSquadA1);
        assertEq(result, true);

        /// Disconnect Safe
        gnosisHelper.updateSafeInterface(rootAddr);
        result = gnosisHelper.createDisconnectSafeTx(childSquadA1);
        assertEq(result, true);

        /// Verify Safe has been removed
        /// Verify module has been removed
        gnosisHelper.updateSafeInterface(childSquadA1Addr);
        bool isPalmeraModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isPalmeraModuleEnabled, false);
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

    function testCannotPromoteToRoot_As_ROOTSAFE_TARGET_SQUAD_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1) =
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

    function testCanPromoteToRoot_As_ROOTSAFE_TARGET_SUPER_SAFE() public {
        (uint256 rootId, uint256 squadA1Id, uint256 childSquadA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1Id);

        /// Promote to Root
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createPromoteToRootTx(squadA1Id);
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
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Whole Tree A is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr), false);
        assertEq(keyperModule.isSafeRegistered(squadA1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadA1Addr), false);
        assertTrue(keyperModule.isSafeRegistered(rootAddr2));
        assertTrue(keyperModule.isSafeRegistered(squadB1Addr));
        assertTrue(keyperModule.isSafeRegistered(childSquadB1Addr));

        /// Remove Whole Tree B
        gnosisHelper.updateSafeInterface(rootAddr2);
        result = gnosisHelper.createRemoveWholeTreeTx();
        assertTrue(result);

        /// Verify Tree is removed
        assertEq(keyperModule.isSafeRegistered(rootAddr2), false);
        assertEq(keyperModule.isSafeRegistered(squadB1Addr), false);
        assertEq(keyperModule.isSafeRegistered(childSquadB1Addr), false);
    }

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
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveWholeTreeTx();
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
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveWholeTreeTx();
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
