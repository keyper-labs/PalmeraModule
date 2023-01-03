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
        bool result = gnosisHelper.disableModuleTx(address(0x1), gnosisSafeAddr);
        assertEq(result, true);
        result = gnosisHelper.disableGuardTx(gnosisSafeAddr);
        assertEq(result, true);
        // Verify guard has been enabled
        if (
            abi.decode(
                StorageAccessible(gnosisSafeAddr).getStorageAt(
                    uint256(Constants.GUARD_STORAGE_SLOT), 2
                ),
                (address)
            ) == address(keyperGuard)
        ) {
            revert Errors.CannotDisableKeyperGuard(address(keyperGuard));
        }
    }

    function testDisableKeyperModule() public {
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, true);
        // Check guard is disabled
        bool result = gnosisHelper.disableModuleTx(address(0x1), gnosisSafeAddr);
        assertEq(result, true);
        // Verify module has been disabled
        isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
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
        bool result = gnosisHelper.disableModuleTx(address(0x1), rootAddr);
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
        result = gnosisHelper.disableModuleTx(address(0x1), groupA1Addr);
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
        result = gnosisHelper.disableModuleTx(address(0x1), groupA1Addr);
        assertEq(result, true);

        // Verify module has been disabled
        bool isKeyperModuleEnabled =
            gnosisHelper.gnosisSafe().isModuleEnabled(address(keyperModule));
        assertEq(isKeyperModuleEnabled, false);
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
        result = gnosisHelper.disableModuleTx(address(0x1), groupA1Addr);
        assertEq(result, true);
        result = gnosisHelper.disableGuardTx(groupA1Addr);
        assertEq(result, true);

        // Verify module has been disabled
        address ZeroAddress = abi.decode(
            StorageAccessible(address(gnosisHelper.gnosisSafe())).getStorageAt(
                uint256(Constants.GUARD_STORAGE_SLOT), 2
            ),
            (address)
        );
        assertEq(ZeroAddress, zeroAddress); // If disable Guard, the address storage will be ZeroAddress (0x0)
    }
}
