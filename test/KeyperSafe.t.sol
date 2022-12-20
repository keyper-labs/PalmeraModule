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
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
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
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
    // Result: Revert
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

    // removeGroup
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromOrg() public {
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
    }

    /// removeGroup when org == superSafe
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromSafeOrgEqSuperSafe() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        // Create a sub safe
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);
        bool result = gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1Name);
        assertEq(result, true);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        uint256 subGroupA1Id =
            keyperModule.getGroupIdBySafe(orgHash, safeSubGroupA1);

        gnosisHelper.updateSafeInterface(rootAddr);
        result = gnosisHelper.createRemoveGroupTx(groupIdA1);
        assertEq(result, true);

        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), false);

        uint256[] memory child;
        (,,,, child,) = keyperModule.getGroupInfo(rootId);
        // Check removed group parent has subSafeGroup A as child an not safeGroupA1
        assertEq(child.length, 1);
        assertEq(child[0] == groupIdA1, false);
        assertEq(child[0] == subGroupA1Id, true);
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), false);
    }

    // ? Org call removeGroup for a group of another org
    // Caller: rootAddr, rootAddr2
    // Caller Type: rootSafe
    // Caller Role: N/A
    // TargerSafe: safeGroupA1, safeGroupA2
    // TargetSafe Type: safe as a child
    // Deploy 4 keyperSafes : following structure
    //           Root                    RootB
    //             |                       |
    //         groupA                 groupB
    // Must Revert if RootOrg1 attempt to remove GroupA2
    function testRevertRemoveGroupFromAnotherOrg() public {
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

    // ? Check disableSafeLeadRoles method success
    // groupA1 removed and it should not have any role
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

    // ! ******************* setRole Test *****************************************

    // setLead as a role at setRole Test
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: userLead
    // TargetSafe Type: EOA
    function testSetSafeLead() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address userEOALead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userEOALead, safeGroupA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userEOALead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeGroupA1, userEOALead), true);

        address safeLead = gnosisHelper.newKeyperSafe(4, 2);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeLead, safeGroupA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );

        assertEq(keyperModule.isSafeLead(safeGroupA1, safeLead), true);
    }

    // Attempt to set a forbidden role to an EOA
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: user
    // TargetSafe Type: EOA
    function testRevertSetRoleForbidden() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        keyperModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeGroupA1, true);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(DataTypes.Role.SUPER_SAFE, user, safeGroupA1, true);
    }

    // Attempt to set a forbidden role to an EOA
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: user
    // TargetSafe Type: EOA
    function testRevertSetRolesToOrgNotRegistered() public {
        (, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);

        address user = address(0xABCDE);

        vm.startPrank(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA1Addr
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, groupA1Id, true);
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
}
