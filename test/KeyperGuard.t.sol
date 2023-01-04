// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {KeyperGuard} from "../src/KeyperGuard.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";
import {console} from "forge-std/console.sol";

contract KeyperGuardTest is DeployHelper, SigningUtils {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    function testDisableKeyperGuard() public {
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

    function testDisableKeyperModule() public {
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Check guard is disabled
        bool result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, gnosisSafeAddr
        );
        assertEq(result, true);
        // Verify module has been disabled
        isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
    }

    function testDisconnectSafe_As_ROOTSAFE_TARGET_SUPERSAFE_SAME_TREE()
        public
    {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        // Remove Group A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectedSafeTx(groupIdA1);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(groupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(groupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ROOTSAFE_SAME_TREE()
        public
    {
        (uint256 rootId,, uint256 subGroupA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Disconnect Safe
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectedSafeTx(subGroupA1Id);
        assertEq(result, true);

        // Verify Safe is disconnected
        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(subGroupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subGroupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Have_children(
    ) public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        gnosisHelper.updateSafeInterface(rootAddr);

        /// Disconnect Safe
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotRemoveGroupBeforeRemoveChild.selector, 1
            )
        );
        keyperModule.disconnectedSafe(rootId);
        vm.stopPrank();

        /// Verify Safe still enabled
        /// Verify module still enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
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

    function testDisconnectSafe_As_ROOTSAFE_TARGET_ITSELF_If_Not_Have_children()
        public
    {
        (uint256 rootId, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        /// Remove Group A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupA1Id);
        assertEq(result, true);

        /// Disconnect Safe
        result = gnosisHelper.createDisconnectedSafeTx(rootId);
        assertEq(result, true);

        /// Verify Safe still enabled
        /// Verify module still enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        /// Verify guard still enabled
        address ZeroAddress = abi.decode(
            StorageAccessible(rootAddr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_SuperSafe_As_SameTree() public {
        (, uint256 groupIdA1, uint256 subGroupA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Remove Group A1
        gnosisHelper.updateSafeInterface(groupA1Addr);
        bool result = gnosisHelper.createRemoveGroupTx(subGroupA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA1Addr
            )
        );
        keyperModule.disconnectedSafe(subGroupA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subGroupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subGroupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    function testCannotDisconnectSafe_As_SuperSafe_As_DifferentTree() public {
        (, uint256 groupIdA1,, uint256 groupIdB1, uint256 subGroupA1Id,) =
        keyperSafeBuilder.setupTwoOrgWithOneRootOneGroupAndOneChildEach(
            orgName,
            groupA1Name,
            root2Name,
            groupBName,
            subGroupA1Name,
            subGroupB1Name
        );

        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);
        address groupB1Addr = keyperModule.getGroupSafeAddress(groupIdB1);

        // Remove Group A1
        gnosisHelper.updateSafeInterface(groupA1Addr);
        bool result = gnosisHelper.createRemoveGroupTx(subGroupA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(groupB1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupB1Addr
            )
        );
        keyperModule.disconnectedSafe(subGroupA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subGroupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subGroupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    function testCannotDisconnectSafe_As_RootSafe_As_DifferentTree() public {
        (uint256 rootIdA,, uint256 rootIdB,, uint256 subGroupA1Id,) =
        keyperSafeBuilder.setupTwoOrgWithOneRootOneGroupAndOneChildEach(
            orgName,
            groupA1Name,
            root2Name,
            groupBName,
            subGroupA1Name,
            subGroupB1Name
        );

        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);
        address rootAddrB = keyperModule.getGroupSafeAddress(rootIdB);

        // Remove Group A1
        gnosisHelper.updateSafeInterface(rootAddrA);
        bool result = gnosisHelper.createRemoveGroupTx(subGroupA1Id);
        assertEq(result, true);

        // Try to Disconnect Safe
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedDisconnectedChildrenGroup.selector);
        keyperModule.disconnectedSafe(subGroupA1Id);
        vm.stopPrank();

        // Verify module still enabled
        gnosisHelper.updateSafeInterface(subGroupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Verify guard still enabled
        address guardAddress = abi.decode(
            StorageAccessible(subGroupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(guardAddress, address(keyperGuard));
    }

    function testDisconnectSafeBeforeToRemoveGroup_One_Level() public {
        (uint256 rootId, uint256 groupIdA1,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        // Disconnect Safe before to remove group
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectedSafeTx(groupIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(groupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(groupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testDisconnectSafeBeforeToRemoveGroup_Two_Level() public {
        (uint256 rootId,, uint256 subGroupIdA1,) = keyperSafeBuilder
            .setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupIdA1);

        // Try to Disconnect Safe before to remove group
        // Disconnect Safe before to remove group
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createDisconnectedSafeTx(subGroupIdA1);
        assertEq(result, true);

        // Verify module has been disabled
        gnosisHelper.updateSafeInterface(subGroupA1Addr);
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
        // Verify guard has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(subGroupA1Addr).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress);
    }

    function testCannotDisconnectSafe_As_SafeLead_As_EOA() public {
        (uint256 rootId,, uint256 childGroupA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = address(0xCBA);

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove group
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakerCaller
            )
        );
        keyperModule.disconnectedSafe(childGroupA1);
        vm.stopPrank();
    }

    function testCannotDisconnectSafe_As_SafeLead_As_SAFE() public {
        (uint256 rootId,, uint256 childGroupA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address fakerCaller = gnosisHelper.newKeyperSafe(3, 1);

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakerCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakerCaller));
        vm.stopPrank();

        // Try to Disconnect Safe before to remove group
        vm.startPrank(fakerCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, fakerCaller
            )
        );
        keyperModule.disconnectedSafe(childGroupA1);
        vm.stopPrank();
    }

    function testCannotDisableKeyperModuleIfGuardEnabled() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        // Try to disable Module from root
        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        bool result =
            gnosisHelper.disableModuleTx(Constants.SENTINEL_ADDRESS, rootAddr);
        assertEq(result, false);

        // Verify module is still enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);

        // Try to disable Module from group
        gnosisHelper.updateSafeInterface(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, groupA1Addr
        );
        assertEq(result, false);

        // Verify module is still enabled
        isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testCannotDisableKeyperModuleAfterRemoveGroup() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        // Remove Group A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupIdA1);
        assertEq(result, true);

        // Try to disable Guard from Group Removed
        gnosisHelper.updateSafeInterface(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, groupA1Addr
        );
        assertEq(result, false);

        // Verify module still enabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testCannotDisableKeyperGuardIfGuardEnabled() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        // Try to disable Guard from root
        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
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

        // Try to disable Guard from group
        gnosisHelper.updateSafeInterface(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
            )
        );
        result = gnosisHelper.disableGuardTx(groupA1Addr);
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

    function testCannotDisableKeyperGuardAfterRemoveGroup() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        // Remove Group A1
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupIdA1);
        assertEq(result, true);

        // Try to disable Guard from Group Removed
        gnosisHelper.updateSafeInterface(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperModule.selector, address(keyperModule)
            )
        );
        result = gnosisHelper.disableModuleTx(
            Constants.SENTINEL_ADDRESS, groupA1Addr
        );
        assertEq(result, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CannotDisableKeyperGuard.selector, address(keyperGuard)
            )
        );
        result = gnosisHelper.disableGuardTx(groupA1Addr);
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
}
