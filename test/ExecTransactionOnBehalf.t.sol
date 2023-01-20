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

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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

        // Set keyperhelper safe to org

        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
        bytes32 orgHash = keyperModule.getOrgBySquad(rootId);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeSquadBAddr, safeSubSubSquadA1Id, true
        );
        vm.stopPrank();

        assertEq(
            keyperModule.isSuperSafe(safeSquadBId, safeSubSubSquadA1Id), false
        );
        keyperHelper.setSafe(safeSquadBAddr);

        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
        keyperHelper.setSafe(rootAddr);

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
    // Caller: safeSquadA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE of safeSubSquadA1
    // TargerSafe: safeSubSquadA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeSquadA1 as superSafe ---
    //              |                        |
    //           safeSubSquadA1 <------------
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

        // Set keyperhelper safe to safeSquadA1
        keyperHelper.setSafe(safeSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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

    // ! ********************** REVERT ********************

    // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSquadA1 is attempting to execute on its superSafe)
    // Caller: safeSubSquadA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe as lead
    //            rootSafe
    //           |
    //  safeSquadA1 <----
    //      |            |
    // safeSubSquadA1 ---
    //      |
    // safeSubSubSquadA1
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

        // Set keyperhelper safe to safeSubSquadA1
        keyperHelper.setSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
            safeSquadA1Addr,
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
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        keyperHelper.setSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(fakeCaller);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSquadA1Addr,
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
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        keyperHelper.setSafe(rootAddr);

        // Try onbehalf with incorrect signers
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
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
            safeSquadA1Addr,
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
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        address fakeReceiver = address(0);

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
            safeSquadA1Addr,
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
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
            abi.encodeWithSelector(Errors.InvalidSafe.selector, address(0))
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
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert InvalidSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SAFE_LEAD
    // TargerSafe: fakeTargetSafe
    // TargetSafe Type: EOA
    function testRevertInvalidSafeExecTransactionOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper safe to org
        keyperHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
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
            abi.encodeWithSelector(Errors.InvalidSafe.selector, fakeTargetSafe)
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

    // Revert NotAuthorizedAsNotSafeLead() execTransactionOnBehalf : safe lead of another org/squad
    // Caller: fakeCaller
    // Caller Type: Safe
    // Caller Role: SAFE_LEAD of the org
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_Different_Target(
    ) public {
        (uint256 rootId, uint256 safeSquadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        keyperHelper.setSafe(rootAddr);
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);

        // Random wallet instead of a safe (EOA)

        vm.startPrank(fakeCaller);
        bool result = gnosisHelper.createAddSquadTx(safeSquadA1, "fakeSquad");
        vm.stopPrank();
        assertEq(result, true);

        // Set keyperhelper safe to org
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
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // testCannot_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_DifferentTree
    //    -> SUPER_SAFE ROLE, caller try call function from another tree
    // Revert NotAuthorizedAsNotRootOrSuperSafe() execTransactionOnBehalf : Super Safe in another tree
    // Deploy 1 org with 2 root safe with 1 squad each, 1 subsquad each
    //           RootA              RootB
    //              |                 |
    //           squadA1 ---┐       squadB1
    //              |       │         |
    //		   ChildSquadA  └--> ChildSquadB
    // Caller: Fake Caller (Super Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubSquadB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_DifferentTree(
    ) public {
        (, uint256 safeSquadA1,,,, uint256 ChildIdB) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address fakeCaller = keyperModule.getSquadSafeAddress(safeSquadA1);
        address ChildB = keyperModule.getSquadSafeAddress(ChildIdB);

        // Set keyperhelper safe to org
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
    // Revert NotAuthorizedAsNotRootOrSuperSafe() execTransactionOnBehalf : Root Safe in another tree
    // Deploy 1 org with 2 root safe with 1 squad each, 1 subsquad each
    //           RootA   ---┐        RootB
    //              |       │          |
    //           squadA1    ├---->  squadB1
    //              |       │          |
    //		   ChildSquadA  └-->  ChildSquadB
    // Caller: Fake Caller (Root Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubSquadB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_DifferentTree(
    ) public {
        (uint256 rootIdA,,, uint256 safeSquadB1,, uint256 ChildIdB) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        // Inthis case the Fake Caller is a Root Safe of the org in another tree
        address fakeCaller = keyperModule.getSquadSafeAddress(rootIdA);
        address safeSquadAddrB1 = keyperModule.getSquadSafeAddress(safeSquadB1);
        address ChildB = keyperModule.getSquadSafeAddress(ChildIdB);

        // Set keyperhelper safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSquadAddrB1,
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
    //    --> SAFE_LEAD from another squad try call function
    // Revert NotAuthorizedAsNotRootOrSuperSafe() execTransactionOnBehalf : Safe Lead in another tree
    // Deploy 1 org with 2 root safe with 1 squad each, 1 subsquad each
    //           RootA               RootB
    //              |                  |
    //           squadA1 ---┬---->  squadB1
    //              |       │          |
    //		   ChildSquadA  └-->  ChildSquadB
    // Caller: Fake Caller (Super Safe)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubSquadB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_Different_Tree(
    ) public {
        (
            uint256 rootIdA,
            uint256 safeSquadA1,
            ,
            uint256 safeSquadB1,
            uint256 ChildIdA,
            uint256 ChildIdB
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address fakeCaller = keyperModule.getSquadSafeAddress(safeSquadA1);
        address safeSquadAddrB1 = keyperModule.getSquadSafeAddress(safeSquadB1);
        address ChildA1 = keyperModule.getSquadSafeAddress(ChildIdA);
        address ChildB = keyperModule.getSquadSafeAddress(ChildIdB);

        // Set keyperhelper safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddrA);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);
        uint256 childSquadA1 = keyperModule.getSquadIdBySafe(orgHash, ChildA1);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, fakeCaller, childSquadA1, true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakeCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSquadAddrB1,
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
    //    --> SAFE_LEAD from another squad try call function
    // Revert NotAuthorizedAsNotRootOrSuperSafe() execTransactionOnBehalf : Safe Lead in another tree by EOA as caller
    // Deploy 1 org with 2 root safe with 1 squad each, 1 subsquad each
    //                  RootA               RootB
    //                    |                   |
    //  ┌---Tx------>  squadA1 ---┬-----> squadB1
    //  │                |        │          |
    // EOA Lead of->ChildSquadA   └---> ChildSquadB
    // Caller: Fake Caller (EOA Safe Lead)
    // Caller Type: Safe
    // Caller Role: Super Safe of the org in another three
    // TargerSafe: safeSubSquadB1
    // TargetSafe Type: safe
    function testCannot_ExecTransactionOnBehalf_SAFE_LEAD_as_EOA_Different_Target(
    ) public {
        (
            uint256 rootIdA,
            uint256 safeSquadA1,
            ,
            uint256 safeSquadB1,
            uint256 ChildIdA,
            uint256 ChildIdB
        ) = keyperSafeBuilder.setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        // Inthis case the Fake Caller is a Super Safe of the org in another tree
        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address safeSquadAddrA1 = keyperModule.getSquadSafeAddress(safeSquadA1);
        address safeSquadAddrB1 = keyperModule.getSquadSafeAddress(safeSquadB1);
        address ChildA1 = keyperModule.getSquadSafeAddress(ChildIdA);
        address ChildB = keyperModule.getSquadSafeAddress(ChildIdB);

        // Set keyperhelper safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddrA);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);
        uint256 childSquadA1 = keyperModule.getSquadIdBySafe(orgHash, ChildA1);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, fakeCaller, childSquadA1, true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakeCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (EOA) over another Squad
        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedAsNotSafeLead.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeSquadAddrB1,
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
            safeSquadAddrA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopPrank();
    }

    // testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_SAFE_is_TARGETS_LEAD
    //    -> SAFE_LEAD_EXEC_ON_BEHALF_ONLY to target squad which caller is lead
    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeSquadA1 ----------------------------------┐
    //              |		         	                     │
    //        ChildSquadA1 <-SAFE Lead Exec on Behalf--- ChildSquadA2
    // Caller: Right Caller (ChildSquadA2 Safe Lead of childSquadA1)
    // Caller Type: Safe
    // Caller Role: Squad of the org in the same tree
    // TargerSafe: ChildSquadA1
    // TargetSafe Type: safe
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 safeSquadA1, uint256 childSquadA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a child safe for squad A2
        address rightCaller = gnosisHelper.newKeyperSafe(4, 2);
        bool result = gnosisHelper.createAddSquadTx(safeSquadA1, "ChildSquadA2");
        assertEq(result, true);

        // Set keyperhelper safe to rightCaller
        keyperHelper.setSafe(rightCaller);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rightCaller,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rightCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, rightCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        gnosisHelper.updateSafeInterface(rightCaller);

        gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(receiver.balance, 2 gwei);
    }

    // testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_EOA_is_TARGETS_LEAD
    //    -> SAFE_LEAD_EXEC_ON_BEHALF_ONLY (EOA) to target squad which caller is lead
    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeSquadA1
    //              |
    //        ChildSquadA1 <-SAFE Lead Exec on Behalf--- EOA Caller
    // Caller: Right Caller (ChildSquadA2 Safe Lead of childSquadA1)
    // Caller Type: Safe
    // Caller Role: Squad of the org in the same tree
    // TargerSafe: ChildSquadA1
    // TargetSafe Type: safe
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_EXEC_ON_BEHALF_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId,, uint256 childSquadA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a a Ramdom Right EOA Caller
        address rightCaller = address(0xCBA);

        // Set keyperhelper safe to org
        bytes memory emptyData;
        bytes memory signatures;

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            rightCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, rightCaller));
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        vm.startPrank(rightCaller);

        keyperModule.execTransactionOnBehalf(
            orgHash,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(receiver.balance, 2 gwei);
        vm.stopPrank();
    }

    // Org with a root safe with 3 child levels: A, B, C
    //    Squad A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_SAFE(
    ) public {
        (uint256 rootId, uint256 safeSquadA1, uint256 childSquadA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSquadA1Addr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a child safe for squad A2
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);
        bool result = gnosisHelper.createAddSquadTx(safeSquadA1, "ChildSquadA2");
        assertEq(result, true);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakeCaller));
        vm.stopPrank();

        // Set keyperhelper safe to fakeCaller
        keyperHelper.setSafe(fakeCaller);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            fakeCaller,
            childSquadA1Addr,
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

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        gnosisHelper.updateSafeInterface(fakeCaller);
        vm.expectRevert("GS013");
        result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
            childSquadA1Addr,
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
    //    Squad A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_EOA(
    ) public {
        (uint256 rootId,, uint256 childSquadA1) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address childSquadA1Addr =
            keyperModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a fakeCaller with Ramdom EOA
        address fakeCaller = address(0xCBA);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childSquadA1,
            true
        );
        assertTrue(keyperModule.isSafeLead(childSquadA1, fakeCaller));
        vm.stopPrank();

        // Value to be sent to the receiver with rightCaller
        bytes memory emptyData;
        bytes memory signatures;
        // Set keyperhelper safe to rootAddr
        keyperHelper.setSafe(childSquadA1Addr);
        bytes memory signatures2 = keyperHelper.encodeSignaturesKeyperTx(
            childSquadA1Addr,
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

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        vm.startPrank(fakeCaller);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            childSquadA1Addr,
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

    // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(keyperModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            keyperModule, attackerContract, gnosisHelper, 30
        );

        (, address attacker, address victim) =
            attackerHelper.setAttackerTree(orgName);

        gnosisHelper.updateSafeInterface(victim);
        attackerContract.setOwners(gnosisHelper.safe().getOwners());

        gnosisHelper.updateSafeInterface(attacker);
        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper
            .encodeSignaturesForAttackKeyperTx(
            attacker, victim, attacker, 5 gwei, emptyData, Enum.Operation(0)
        );

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
