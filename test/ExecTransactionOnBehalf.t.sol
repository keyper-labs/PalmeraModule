// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/ReentrancyAttackHelper.t.sol";
import "./helpers/DeployHelper.t.sol";

contract ExecTransactionOnBehalf is DeployHelper {
    function setUp() public {
        DeployHelper.deployAllContracts(60);
    }

    // ! ********************** ROOT_SAFE ROLE ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
    ) public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
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
    // TargerSafe: safeSubSquadA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1          |
    //              |                 |
    //           safeSubSquadA1 <-----
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree_2_levels(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to org

        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
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

    // Caller Info: SAFE_LEAD(role), SAFE(type), squadB(hierachie)
    // TargerSafe: safeSubSubSquadA1
    // TargetSafe Type: squad (not a child)
    //            rootSafe
    //           |        |
    //  safeSquadA1       safeSquadB
    //      |
    // safeSubSquadA1
    //      |
    // safeSubSubSquadA1
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD()
        public
    {
        (uint256 rootId,, uint256 safeSquadBId,, uint256 safeSubSubSquadA1Id) =
        keyperSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSubSquadA1Name
        );
        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadBAddr = keyperModule.getSquadSafeAddress(safeSquadBId);
        address safeSubSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSubSquadA1Id);

        vm.deal(safeSubSubSquadA1Addr, 100 gwei);
        vm.deal(safeSquadBAddr, 100 gwei);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeSquadBAddr, safeSubSubSquadA1Id, true
        );
        vm.stopPrank();

        assertEq(
            keyperModule.isSuperSafe(safeSquadBId, safeSubSubSquadA1Id), false
        );
        keyperHelper.setGnosisSafe(safeSquadBAddr);

        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            safeSquadBAddr,
            safeSubSubSquadA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeSquadBAddr,
            safeSubSubSquadA1Addr,
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
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        keyperHelper.setGnosisSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Set safe_lead role to fake caller
        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, callerEOA, rootId, true);
        vm.stopPrank();
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
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

    // execTransactionOnBehalf when is Any EOA, passing the signature of the Root/Super Safe of Target Safe
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // SuperSafe: rootAddr
    // TargerSafe: safeSubSquadA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1          |
    //              |                 |
    //           safeSubSquadA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Root Safe sign args
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 25 gwei);
    }

    // // ! ********************** SUPER_SAFE ROLE ********************

    // // execTransactionOnBehalf
    // // Caller: safeSquadA1
    // // Caller Type: safe
    // // Caller Role: SUPER_SAFE of safeSubSquadA1
    // // TargerSafe: safeSubSquadA1
    // // TargetSafe Type: safe
    // //            rootSafe
    // //               |
    // //           safeSquadA1 as superSafe ---
    // //              |                        |
    // //           safeSubSquadA1 <------------
    function testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree(
    ) public {
        (, uint256 safeSquadA1Id, uint256 safeSubSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address safeSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSquadA1Id);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        // Send ETH to squad&subsquad
        vm.deal(safeSquadA1Addr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to safeSquadA1
        keyperHelper.setGnosisSafe(safeSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            safeSquadA1Addr,
            safeSubSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        /// Verify if the safeSquadA1Addr have the role to execute, executionTransactionOnBehalf
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );

        // Execute on safe tx
        gnosisHelper.updateSafeInterface(safeSquadA1Addr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            safeSquadA1Addr,
            safeSubSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // // ! ********************** REVERT ********************

    // Revert: "GS026" execTransactionOnBehalf when is Any EOA, passing the wrong signature of the Root/Super Safe of Target Safe
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // SuperSafe: rootAddr
    // TargerSafe: safeSubSquadA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1          |
    //              |                 |
    //           safeSubSquadA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_WRONG_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Target Safe signed args
        keyperHelper.setGnosisSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(callerEOA);
        vm.expectRevert("GS020");
        keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert: "GS013" execTransactionOnBehalf when is Any EOA, (invalid signatures provided)
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // SuperSafe: rootAddr
    // TargerSafe: safeSubSquadA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1          |
    //              |                 |
    //           safeSubSquadA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_INVALID_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Root Safe sign args
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(callerEOA);
        vm.expectRevert("GS020");
        keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSquadA1 is attempting to execute on its superSafe)
    // // Caller: safeSubSquadA1
    // // Caller Type: safe
    // // Caller Role: SUPER_SAFE
    // // TargerSafe: safeSquadA1
    // // TargetSafe Type: safe as lead
    // //            rootSafe
    // //           |
    // //  safeSquadA1 <----
    // //      |            |
    // // safeSubSquadA1 ---
    // //      |
    // // safeSubSubSquadA1
    function testRevertSuperSafeExecOnBehalf() public {
        (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1,) =
        keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(subSquadIdA1);

        // Send ETH to org&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSquadA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to safeSubSquadA1
        keyperHelper.setGnosisSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            safeSubSquadA1Addr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(safeSubSquadA1Addr);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSubSquadA1Addr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    // Revert "GS013" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        keyperHelper.setGnosisSafe(rootAddr);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        gnosisHelper.updateSafeInterface(rootAddr);
        vm.expectRevert("GS013");
        // Execute invalid OnBehalf function
        gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // Revert ZeroAddressProvided() execTransactionOnBehalf when arg "to" is address(0)
    // // Scenario 1
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE
    // // TargerSafe: safeSquadA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeSquadA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            fakeReceiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // Revert ZeroAddressProvided() execTransactionOnBehalf when param "targetSafe" is address(0)
    // // Scenario 2
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE
    // // TargerSafe: safeSquadA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeSquadA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, address(0)
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            address(0),
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // Revert ZeroAddressProvided() execTransactionOnBehalf when param "org" is address(0)
    // // Scenario 3
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE
    // // TargerSafe: safeSquadA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeSquadA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
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
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // Revert InvalidGnosisSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE, SAFE_LEAD
    // // TargerSafe: fakeTargetSafe
    // // TargetSafe Type: EOA
    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakeTargetSafe
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            fakeTargetSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(keyperModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            keyperModule, attackerContract, gnosisHelper, 30
        );

        (bytes32 orgName, address orgAddr, address attacker, address victim) =
            attackerHelper.setAttackerTree(orgName);

        gnosisHelper.updateSafeInterface(victim);
        attackerContract.setOwners(gnosisHelper.gnosisSafe().getOwners());

        gnosisHelper.updateSafeInterface(attacker);
        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper
            .encodeSignaturesForAttackKeyperTx(
            orgName,
            attacker,
            victim,
            attacker,
            5 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.expectRevert(Errors.TxOnBehalfExecutedFailed.selector);
        bool result = attackerContract.performAttack(
            orgHash,
            orgAddr,
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
