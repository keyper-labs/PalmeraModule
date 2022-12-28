// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import "./helpers/KeyperModuleHelper.t.sol";
import "./helpers/ReentrancyAttackHelper.t.sol";
import "./helpers/KeyperSafeBuilder.t.sol";
import "./helpers/DeployHelper.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {Attacker} from "../src/ReentrancyAttack.sol";
import {console} from "forge-std/console.sol";

contract TestKeyperSafe is SigningUtils, DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts();
    }

    // ! ********************** authority Test **********************************

    // Checks if authority == keyperRoles
    function testAuthorityAddress() public {
        assertEq(
            address(keyperModule.authority()), address(keyperRolesDeployed)
        );
    }

    // ! ********************** createSafeFactory Test **************************

    // Checks if a safe is created successfully from Module
    function testCreateSafeFromModule() public {
        address newSafe = keyperHelper.createSafeProxy(4, 2);
        assertFalse(newSafe == address(0));
        // Verify newSafe has keyper modulle enabled
        GnosisSafe safe = GnosisSafe(payable(newSafe));
        bool isKeyperModuleEnabled =
            safe.isModuleEnabled(address(keyperHelper.keyper()));
        assertEq(isKeyperModuleEnabled, true);
    }

    // ! ********************** Allow/Deny list Test ********************

    // Revert AddresNotAllowed() execTransactionOnBehalf (safeGroupA1 is not on AllowList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> safeGroupA1
    // Target Info: Type-> SAFE, Name -> safeSubGroupA1, Hierarchy related to caller -> NOT_ALLOW_LIST
    function testRevertSuperSafeExecOnBehalfIsNotAllowList() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(groupA1Addr, 100 gwei);
        vm.deal(subGroupA1Addr, 100 gwei);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableAllowlist();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(groupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA1Addr,
            subGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Execute on behalf function
        vm.startPrank(groupA1Addr);
        vm.expectRevert(Errors.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            subGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeGroupA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> safeGroupA1
    // Target Info: Type-> SAFE, Name -> safeSubGroupA1, Hierarchy related to caller -> DENY_LIST
    function testRevertSuperSafeExecOnBehalfIsDenyList() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(groupA1Addr, 100 gwei);
        vm.deal(subGroupA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(groupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA1Addr,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Execute on behalf function
        vm.startPrank(groupA1Addr);
        vm.expectRevert(Errors.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeGroupA1 is on DeniedList)
    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> safeGroupA1
    // Target Info: Type-> SAFE, Name -> safeSubGroupA1, Hierarchy related to caller -> DENY_LIST
    function testDisableDenyHelperList() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(groupA1Addr, 100 gwei);
        vm.deal(subGroupA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        /// Disable allowlist
        keyperModule.disableDenyHelper();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(groupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA1Addr,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Execute on behalf function
        vm.startPrank(groupA1Addr);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // ! ******************** registerOrg Test *************************************

    // Revert ("UNAUTHORIZED") registerOrg (address that has no roles)
    function testRevertAuthForRegisterOrgTx() public {
        address caller = address(0x1);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        keyperRolesContract.setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD), caller, Constants.ADD_OWNER, true
        );
    }

    // ! ******************** removeGroup Test *************************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> safeGroupA1, Hierarchy related to caller -> SAME_TREE
    function testCan_RemoveGroup_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree()
        public
    {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(rootId, groupA1Id), false);

        // Check safeSubGroupA1 is now a child of org
        assertEq(keyperModule.isTreeMember(rootId, subGroupA1Id), true);
        // Check org is parent of safeSubGroupA1
        assertEq(keyperModule.isSuperSafe(rootId, subGroupA1Id), true);

        // Check removed group parent has subSafeGroup A as child an not safeGroupA1
        uint256[] memory child;
        (,,,, child,) = keyperModule.getGroupInfo(rootId);
        assertEq(child.length, 1);
        assertEq(child[0] == groupA1Id, false);
        assertEq(child[0] == subGroupA1Id, true);
        assertEq(keyperModule.isTreeMember(rootId, groupA1Id), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> groupB, Hierarchy related to caller -> DIFFERENT_TREE
    function testCannot_RemoveGroup_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentTree(
    ) public {
        (uint256 rootIdA, uint256 groupAId, uint256 rootIdB, uint256 groupBId) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(groupBId);
        vm.stopPrank();

        address rootBAddr = keyperModule.getGroupSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(groupAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> groupA
    // Target Info: Type-> SAFE, Name -> subGroupA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testCan_RemoveGroup_SUPER_SAFE_as_SAFE_is_SUPER_SAFE_SameTree()
        public
    {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address groupAAddr = keyperModule.getGroupSafeAddress(groupA1Id);

        gnosisHelper.updateSafeInterface(groupAAddr);
        bool result = gnosisHelper.createRemoveGroupTx(subGroupA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(groupA1Id, subGroupA1Id), false);
        assertEq(keyperModule.isTreeMember(rootId, subGroupA1Id), false);

        // Check supersafe has not any children
        uint256[] memory child;
        (,,,, child,) = keyperModule.getGroupInfo(groupA1Id);
        assertEq(child.length, 0);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> groupA
    // Target Info: Type-> SAFE, Name -> groupB, Hierarchy related to caller -> DIFFERENT_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveGroup_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_DifferentTree(
    ) public {
        (, uint256 groupAId,, uint256 groupBId,,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupAndOneChildEach(
            orgName,
            groupA1Name,
            root2Name,
            groupBName,
            subGroupA1Name,
            subGroupB1Name
        );

        address groupAAddr = keyperModule.getGroupSafeAddress(groupAId);
        vm.startPrank(groupAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotSuperSafe.selector);
        keyperModule.removeGroup(groupBId);
        vm.stopPrank();

        address groupBAddr = keyperModule.getGroupSafeAddress(groupBId);
        vm.startPrank(groupBAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotSuperSafe.selector);
        keyperModule.removeGroup(groupAId);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> Group, Name -> groupA
    // Target Info: Type-> SAFE, Name -> subsubGroupA, Hierarchy related to caller -> SAME_TREE,NOT_DIRECT_CHILDREN
    function testCannot_RemoveGroup_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_SameTree(
    ) public {
        (, uint256 groupAId,, uint256 subSubGroupA1) = keyperSafeBuilder
            .setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );

        address groupAAddr = keyperModule.getGroupSafeAddress(groupAId);
        vm.startPrank(groupAAddr);
        vm.expectRevert(Errors.NotAuthorizedAsNotSuperSafe.selector);
        keyperModule.removeGroup(subSubGroupA1);
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> Root, Name -> rootA
    // Target Info: Type-> SAFE, Name -> groupA, Hierarchy related to caller -> SAME_TREE, CHILDREN
    function testRemoveGroupAndCheckDisables() public {
        (uint256 rootId, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);

        (,,,,, uint256 superSafe) = keyperModule.getGroupInfo(groupA1Id);
        bytes32 orgHash = keyperModule.getOrgByGroup(superSafe);
        (,, address superSafeAddr,,) = keyperModule.groups(orgHash, superSafe);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupA1Id);
        assertEq(result, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
    }

    // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(keyperModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            keyperModule, attackerContract, gnosisHelper, 30
        );

        (address rootAddr, address attacker, address victim) =
            attackerHelper.setAttackerTree(orgName);

        gnosisHelper.updateSafeInterface(victim);
        attackerContract.setOwners(gnosisHelper.gnosisSafe().getOwners());

        gnosisHelper.updateSafeInterface(attacker);
        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper
            .encodeSignaturesForAttackKeyperTx(
            attacker, victim, attacker, 5 gwei, emptyData, Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.expectRevert(Errors.TxOnBehalfExecutedFailed.selector);
        bool result = attackerContract.performAttack(
            orgHash,
            victim,
            attacker,
            5 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );

        assertEq(result, false);

        // This is the expected behavior since the nonReentrant modifier is blocking the attacker from draining the victim's funds nor transfer any amount
        assertEq(attackerContract.getBalanceFromSafe(victim), 100 gwei);
        assertEq(attackerContract.getBalanceFromAttacker(), 0);
    }

    function testCan_hasNotPermissionOverTarget_is_root_of_target() public {
        (uint256 rootId, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupAddr = keyperModule.getGroupSafeAddress(groupA1Id);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        bool result = keyperModule.hasNotPermissionOverTarget(
            rootAddr, orgHash, groupAddr
        );
        assertFalse(result);
    }

    function testCan_hasNotPermissionOverTarget_is_not_root_of_target()
        public
    {
        (uint256 rootId, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupAddr = keyperModule.getGroupSafeAddress(groupA1Id);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        bool result = keyperModule.hasNotPermissionOverTarget(
            groupAddr, orgHash, rootAddr
        );
        assertTrue(result);
    }

    function testCan_hasNotPermissionOverTarget_is_super_safe_of_target()
        public
    {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupAddr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupAddr = keyperModule.getGroupSafeAddress(subGroupA1Id);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        bool result = keyperModule.hasNotPermissionOverTarget(
            groupAddr, orgHash, subGroupAddr
        );
        assertFalse(result);
    }

    function testCan_hasNotPermissionOverTarget_is_not_super_safe_of_target()
        public
    {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupAddr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupAddr = keyperModule.getGroupSafeAddress(subGroupA1Id);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        bool result = keyperModule.hasNotPermissionOverTarget(
            subGroupAddr, orgHash, groupAddr
        );
        assertTrue(result);
    }
}
