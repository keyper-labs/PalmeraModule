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

contract ExecTransactionOnBehalf is DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts();
    }

    // ! ********************** ROOT_SAFE ROLE ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
    ) public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargerSafe: safeSubGroupA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1          |
    //              |                 |
    //           safeSubGroupA1 <-----
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree_2_levels(
    ) public {
        (uint256 rootId,, uint256 safeSubGroupA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubGroupA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to org
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeSubGroupA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeSubGroupA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 25 gwei);
    }

    // ! ********************** SAFE_LEAD ROLE ********************

    // Caller Info: SAFE_LEAD(role), SAFE(type), groupB(hierachie)
    // TargerSafe: safeSubSubGroupA1
    // TargetSafe Type: group (not a child)
    //            rootSafe
    //           |        |
    //  safeGroupA1       safeGroupB
    //      |
    // safeSubGroupA1
    //      |
    // safeSubSubGroupA1
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD()
        public
    {
        (uint256 rootId,, uint256 safeGroupBId,, uint256 safeSubSubGroupA1Id) =
        keyperSafeBuilder.setUpBaseOrgTree(
            orgName, groupA1Name, groupBName, subGroupA1Name, subSubgroupA1Name
        );
        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupBAddr = keyperModule.getGroupSafeAddress(safeGroupBId);
        address safeSubSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubSubGroupA1Id);

        vm.deal(safeSubSubGroupA1Addr, 100 gwei);
        vm.deal(safeGroupBAddr, 100 gwei);

        vm.startPrank(rootAddr);
        bytes32 orgHash = keyperModule.getOrgByGroup(rootId);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeGroupBAddr, safeSubSubGroupA1Id, true
        );
        vm.stopPrank();

        assertEq(
            keyperModule.isSuperSafe(safeGroupBId, safeSubSubGroupA1Id), false
        );
        keyperHelper.setGnosisSafe(safeGroupBAddr);

        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupBAddr,
            safeSubSubGroupA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeSubSubGroupA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 12 gwei);
    }

    // execTransactionOnBehalf when SafeLead of an Org as EOA
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_as_EOA_is_TARGETS_LEAD()
        public
    {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        keyperHelper.setGnosisSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Set safe_lead role to fake caller
        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, callerEOA, rootId, true);
        vm.stopPrank();
        bytes memory emptyData;
        bytes memory signatures;
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // ! ********************** SUPER_SAFE ROLE ********************

    // execTransactionOnBehalf
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE of safeSubGroupA1
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
    function testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree(
    ) public {
        (uint256 rootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeGroupA1Id);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(safeGroupA1Addr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1Addr,
            safeSubGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        /// Verify if the safeGroupA1Addr have the role to execute, executionTransactionOnBehalf
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );

        // Execute on safe tx
        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeSubGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // ! ********************** REVERT ********************

    // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubGroupA1 is attempting to execute on its superSafe)
    // Caller: safeSubGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as lead
    //            rootSafe
    //           |
    //  safeGroupA1 <----
    //      |            |
    // safeSubGroupA1 ---
    //      |
    // safeSubSubGroupA1
    function testRevertSuperSafeExecOnBehalf() public {
        (uint256 rootId, uint256 groupIdA1, uint256 subGroupIdA1,) =
        keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(subGroupIdA1);

        // Send ETH to org&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to safeSubGroupA1
        keyperHelper.setGnosisSafe(safeSubGroupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeSubGroupA1Addr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.startPrank(safeSubGroupA1Addr);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    // Revert "UNAUTHORIZED" execTransactionOnBehalf (Caller is an EOA but he's not the lead (no role provided to EOA))
    // Caller: fakeCaller
    // Caller Type: EOA
    // Caller Role: N/A (NO ROLE PROVIDED)
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.startPrank(fakeCaller);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert "GS026" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert("GS013");
        // Execute invalid OnBehalf function
        gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when arg "to" is address(0)
    // Scenario 1
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            fakeReceiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "targetSafe" is address(0)
    // Scenario 2
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, address(0)
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
            address(0),
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "org" is address(0)
    // Scenario 3
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.OrgNotRegistered.selector, address(0))
        );
        keyperModule.execTransactionOnBehalf(
            bytes32(0),
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert InvalidGnosisSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SAFE_LEAD
    // TargerSafe: fakeTargetSafe
    // TargetSafe Type: EOA
    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakeTargetSafe
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
            fakeTargetSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert NotAuthorizedAsNotSafeLead() execTransactionOnBehalf : safe lead of another org/group
    // Caller: fakeCaller
    // Caller Type: Safe
    // Caller Role: SAFE_LEAD of the org
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_Different_Target(
    ) public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);

        // Random wallet instead of a safe (EOA)

        vm.startPrank(fakeCaller);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "fakeGroup");
        vm.stopPrank();
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, fakeCaller, rootId, true);
        vm.stopPrank();

        //Vefiry that fakeCaller is a safe lead
        assertEq(keyperModule.isSafeLead(rootId, fakeCaller), true);

        vm.startPrank(fakeCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // testCannot_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_DifferentTree
    //    -> SUPER_SAFE ROLE, caller try call function from another tree
    // Revert NotAuthorizedAsNotSuperSafe() execTransactionOnBehalf : Super Safe in another tree
    // Deploy 1 org with 2 root safe with 1 group each, 1 subgroup each
    //           RootA              RootB
    //              |                 |
    //           groupA1 ---┐       groupB1
    //              |       │         |
    //		   ChildGroupA  └--> ChildGroupB
    // Caller: Fake Caller (Super Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubGroupB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_DifferentTree(
    ) public {
        (, uint256 safeGroupA1,, uint256 safeGroupB1) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address fakeCaller = keyperModule.getGroupSafeAddress(safeGroupA1);
        address ChildA = gnosisHelper.newKeyperSafe(4, 2);
        address ChildB = gnosisHelper.newKeyperSafe(4, 2);
        assertTrue(ChildA != ChildB);

        // Create a child safe for group A
        gnosisHelper.updateSafeInterface(ChildA);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "ChildGroupA");
        assertEq(result, true);

        // Create a child safe for group B
        gnosisHelper.updateSafeInterface(ChildB);
        result = gnosisHelper.createAddGroupTx(safeGroupB1, "ChildGroupB");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Execute on behalf function from a not authorized caller
        vm.startPrank(fakeCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            ChildB,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // 3: testCannot_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_DifferentTree
    //    --> ROOTSAFE from another tree try call function
    // Revert NotAuthorizedAsNotSuperSafe() execTransactionOnBehalf : Root Safe in another tree
    // Deploy 1 org with 2 root safe with 1 group each, 1 subgroup each
    //           RootA   ---┐        RootB
    //              |       │          |
    //           groupA1    ├---->  groupB1
    //              |       │          |
    //		   ChildGroupA  └-->  ChildGroupB
    // Caller: Fake Caller (Root Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubGroupB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_DifferentTree(
    ) public {
        (uint256 rootIdA,,, uint256 safeGroupB1) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        // Inthis case the Fake Caller is a Root Safe of the org in another tree
        address fakeCaller = keyperModule.getGroupSafeAddress(rootIdA);
        address safeGroupAddrB1 = keyperModule.getGroupSafeAddress(safeGroupB1);
        address ChildB = gnosisHelper.newKeyperSafe(4, 2);

        // Create a child safe for group B
        gnosisHelper.updateSafeInterface(ChildB);
        bool result = gnosisHelper.createAddGroupTx(safeGroupB1, "ChildGroupB");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        vm.startPrank(fakeCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupAddrB1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();

        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            ChildB,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_Different_Target
    //    --> SAFE_LEAD from another group try call function
    // Revert NotAuthorizedAsNotSuperSafe() execTransactionOnBehalf : Safe Lead in another tree
    // Deploy 1 org with 2 root safe with 1 group each, 1 subgroup each
    //           RootA               RootB
    //              |                  |
    //           groupA1 ---┬---->  groupB1
    //              |       │          |
    //		   ChildGroupA  └-->  ChildGroupB
    // Caller: Fake Caller (Super Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubGroupB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_Different_Tree(
    ) public {
        (uint256 rootIdA, uint256 safeGroupA1,, uint256 safeGroupB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address fakeCaller = keyperModule.getGroupSafeAddress(safeGroupA1);
        address safeGroupAddrB1 = keyperModule.getGroupSafeAddress(safeGroupB1);
        address ChildA1 = gnosisHelper.newKeyperSafe(4, 2);
        address ChildB = gnosisHelper.newKeyperSafe(4, 2);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);

        // Create a child safe for group A1
        gnosisHelper.updateSafeInterface(ChildA1);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "ChildGroupA1");
        assertEq(result, true);
        uint256 childGroupA1 = keyperModule.getGroupIdBySafe(orgHash, ChildA1);

        // Create a child safe for group B
        gnosisHelper.updateSafeInterface(ChildB);
        result = gnosisHelper.createAddGroupTx(safeGroupB1, "ChildGroupB");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, fakeCaller, childGroupA1, true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakeCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupAddrB1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );

        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            ChildB,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_EOA_Different_Target
    //    --> SAFE_LEAD from another group try call function
    // Revert NotAuthorizedAsNotSuperSafe() execTransactionOnBehalf : Safe Lead in another tree by EOA as caller
    // Deploy 1 org with 2 root safe with 1 group each, 1 subgroup each
    //                  RootA               RootB
    //                    |                   |
    //  ┌---Tx------>  groupA1 ---┬-----> groupB1
    //  │                |        │          |
    // EOA Lead of->ChildGroupA   └---> ChildGroupB
    // Caller: Fake Caller (EOA Safe Lead)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubGroupB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_EOA_Different_Target(
    ) public {
        (uint256 rootIdA, uint256 safeGroupA1,, uint256 safeGroupB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address safeGroupAddrA1 = keyperModule.getGroupSafeAddress(safeGroupA1);
        address safeGroupAddrB1 = keyperModule.getGroupSafeAddress(safeGroupB1);
        address ChildA1 = gnosisHelper.newKeyperSafe(4, 2);
        address ChildB = gnosisHelper.newKeyperSafe(4, 2);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);

        // Create a child safe for group A1
        gnosisHelper.updateSafeInterface(ChildA1);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "ChildGroupA1");
        assertEq(result, true);
        uint256 childGroupA1 = keyperModule.getGroupIdBySafe(orgHash, ChildA1);

        // Create a child safe for group B
        gnosisHelper.updateSafeInterface(ChildB);
        result = gnosisHelper.createAddGroupTx(safeGroupB1, "ChildGroupB");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, fakeCaller, childGroupA1, true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakeCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedAsNotSafeLead.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupAddrB1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.expectRevert(Errors.NotAuthorizedAsNotSafeLead.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            ChildB,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.expectRevert(Errors.NotAuthorizedAsNotSafeLead.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupAddrA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_SAFE_is_TARGETS_LEAD
    //    -> SAFE_LEAD_EXEC_ON_BEHALF_ONLY to target group which caller is lead
    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1 ----------------------------------┐
    //              |		         	                     │
    //        ChildGroupA1 <-SAFE Lead Exec on Behalf--- ChildGroupA2
    // Caller: Right Caller (ChildGroupA2 Safe Lead of childGroupA1)
    // Caller Type: Safe
    // Caller Role: Group of the org in the same tree
    // TargerSafe: ChildGroupA1
    // TargetSafe Type: safe
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 safeGroupA1, uint256 childGroupA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a child safe for group A2
        address rightCaller = gnosisHelper.newKeyperSafe(4, 2);
        gnosisHelper.updateSafeInterface(rightCaller);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "ChildGroupA2");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to rightCaller
        keyperHelper.setGnosisSafe(rightCaller);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rightCaller,
            childGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rightCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, rightCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        gnosisHelper.updateSafeInterface(rightCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            childGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_EOA_is_TARGETS_LEAD
    //    -> SAFE_LEAD_EXEC_ON_BEHALF_ONLY (EOA) to target group which caller is lead
    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1
    //              |
    //        ChildGroupA1 <-SAFE Lead Exec on Behalf--- EOA Caller
    // Caller: Right Caller (ChildGroupA2 Safe Lead of childGroupA1)
    // Caller Type: Safe
    // Caller Role: Group of the org in the same tree
    // TargerSafe: ChildGroupA1
    // TargetSafe Type: safe
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId,, uint256 childGroupA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address rightCaller = address(0xCBA);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rightCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, rightCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        vm.startPrank(rightCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            childGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // Missing scenarios:

    // Org with a root safe with 3 child levels: A, B, C
    //    Group A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildGroup_over_RootSafe_With_SAFE(
    ) public {
        (uint256 rootId, uint256 safeGroupA1, uint256 childGroupA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeGroupA1Addr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a child safe for group A2
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);
        gnosisHelper.updateSafeInterface(fakeCaller);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "ChildGroupA2");
        assertEq(result, true);

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakeCaller));
        vm.stopPrank();

        // Set keyperhelper gnosis safe to fakeCaller
        keyperHelper.setGnosisSafe(fakeCaller);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            fakeCaller,
            childGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes memory signatures2 = keyperHelper.encodeSignaturesKeyperTx(
            fakeCaller,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );

        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        gnosisHelper.updateSafeInterface(fakeCaller);
        vm.expectRevert("GS013");
        result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            childGroupA1Addr,
            receiver,
            2 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
        assertEq(receiver.balance, 0 gwei);
    }

    // Org with a root safe with 3 child levels: A, B, C
    //    Group A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildGroup_over_RootSafe_With_EOA(
    ) public {
        (uint256 rootId,, uint256 childGroupA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address childGroupA1Addr =
            keyperModule.getGroupSafeAddress(childGroupA1);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Send ETH to group&subgroup
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childGroupA1Addr, 100 gwei);

        // Create a fakeCaller with Ramdom EOA
        address fakeCaller = address(0xCBA);

        // Set Safe Role in Safe Group A1 over Child Group A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childGroupA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childGroupA1, fakeCaller));
        vm.stopPrank();

        // Value to be sent to the receiver with rightCaller
        bytes memory emptyData;
        bytes memory signatures;
        // Set keyperhelper gnosis safe to rootAddr
        keyperHelper.setGnosisSafe(childGroupA1Addr);
        bytes memory signatures2 = keyperHelper.encodeSignaturesKeyperTx(
            childGroupA1Addr,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );

        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Group Safe in another Three
        vm.startPrank(fakeCaller);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            childGroupA1Addr,
            receiver,
            50 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
        assertTrue(result);
        assertEq(receiver.balance, 50 gwei); // Indirect Validattion
    }
}
