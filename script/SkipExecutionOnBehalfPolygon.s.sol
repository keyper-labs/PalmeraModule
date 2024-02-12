// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/SigningUtils.sol";
import "../test/helpers/SkipSetupEnvPolygon.s.sol";
import {Errors} from "../libraries/Errors.sol";

contract SkipSeveralScenariosPolygon is Script, SkipSetupEnvPolygon {
    function setUp() public {
        // Set up env
        run();
        // testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
        // ); ✅
        testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES(
        ); // ✅
            // testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree();// ✅
            // testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_WRONG_SIGNATURES(); // ✅
            // testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_INVALID_SIGNATURES(); // ✅
            // testRevertInvalidSignatureExecOnBehalf(); // ✅
            // testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree(); // ✅
            // testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo(); // ✅
            // testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(); // ✅
            // testRevertInvalidGnosisSafeExecTransactionOnBehalf(); // ✅
    }
    // ! ********************** ROOT_SAFE ROLE ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Receiver address Test Execution On Behalf: ", receiver);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeSquadA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        // (sent, data) = receiverAddr.call{value: 1e5 gwei}("");
        // require(sent, "Failed to send Ether");

        // Set keyperhelper gnosis safe to org
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function

        bool result = execTransactionOnBehalfTx(
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
        vm.stopBroadcast();
    }

    // execTransactionOnBehalf when SafeLead of an Org as EOA
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    // function testCan_ExecTransactionOnBehalf_SAFE_LEAD_as_EOA_is_TARGETS_LEAD()
    //     public
    // {
    //     vm.startBroadcast();
    //     (uint256 rootId,) = setupRootOrgAndOneSquad(orgName, squadA1Name);

    //     address rootAddr = keyperModule.getSquadSafeAddress(rootId);
    //     console.log("Root address Test Execution On Behalf: ", rootAddr);

    //     // Random wallet instead of a safe (EOA)
    //     address callerEOA = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);

    //     // Set safe_lead role to fake caller
    //     setGnosisSafe(rootAddr);
    //     console.log("Msg Sender: ", msg.sender);
    //     bool result = createSetRoleTx(uint8(DataTypes.Role.SAFE_LEAD), callerEOA, rootId, true);
    //     bytes memory emptyData;
    //     bytes memory signatures;

    //     vm.startPrank(callerEOA);
    //     result = keyperModule.execTransactionOnBehalf(
    //         orgHash,
    //         rootAddr,
    //         rootAddr,
    //         receiver,
    //         2 gwei,
    //         emptyData,
    //         Enum.Operation(0),
    //         signatures
    //     );
    //     assertEq(result, true);
    //     assertEq(receiver.balance, 4 gwei);
    //     vm.stopPrank();
    //     vm.stopBroadcast();
    // }

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
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSquadA1Id) =
            setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(receiver);

        // Owner of Root Safe sign args
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

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
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (, uint256 safeSquadA1Id, uint256 safeSubSquadA1Id) =
            setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address safeSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSquadA1Id);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) =
            safeSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Set keyperhelper gnosis safe to safeSquadA1
        setGnosisSafe(safeSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
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
        setGnosisSafe(safeSquadA1Addr);
        bool result = execTransactionOnBehalfTx(
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
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSquadA1Id) =
            setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Target Safe signed args
        setGnosisSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // vm.startPrank(callerEOA);
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
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSquadA1Id) =
            setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(safeSubSquadA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Root Safe sign args
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeInvalidSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // vm.startPrank(callerEOA);
        vm.expectRevert("GS026");
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
        vm.stopBroadcast();
    }

    // // // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSquadA1 is attempting to execute on its superSafe)
    // // // Caller: safeSubSquadA1
    // // // Caller Type: safe
    // // // Caller Role: SUPER_SAFE
    // // // TargerSafe: safeSquadA1
    // // // TargetSafe Type: safe as lead
    // // //            rootSafe
    // // //           |
    // // //  safeSquadA1 <----
    // // //      |            |
    // // // safeSubSquadA1 ---
    // // //      |
    // // // safeSubSubSquadA1
    // function testRevertSuperSafeExecOnBehalf() public {
    //     vm.startBroadcast();
    //     (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1,) =
    //     keyperSafeBuilder.setupOrgFourTiersTree(
    //         orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
    //     );

    //     address rootAddr = keyperModule.getSquadSafeAddress(rootId);
    //     address safeSquadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
    //     address safeSubSquadA1Addr =
    //         keyperModule.getSquadSafeAddress(subSquadIdA1);

    //     // Send ETH to org&subsquad
    //     vm.deal(rootAddr, 100 gwei);
    //     vm.deal(safeSquadA1Addr, 100 gwei);

    //     // Set keyperhelper gnosis safe to safeSubSquadA1
    //     keyperHelper.setGnosisSafe(safeSubSquadA1Addr);
    //     bytes memory emptyData;
    //     bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
    //         orgHash,
    //         safeSubSquadA1Addr,
    //         safeSquadA1Addr,
    //         receiver,
    //         2 gwei,
    //         emptyData,
    //         Enum.Operation(0)
    //     );

    //     vm.startPrank(safeSubSquadA1Addr);
    //     vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
    //     bool result = keyperModule.execTransactionOnBehalf(
    //         orgHash,
    //         safeSubSquadA1Addr,
    //         safeSquadA1Addr,
    //         receiver,
    //         2 gwei,
    //         emptyData,
    //         Enum.Operation(0),
    //         signatures
    //     );
    //     assertEq(result, false);
    //     vm.stopBroadcast();
    // }

    // Revert "GS013" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeSquadA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);

        // Try onbehalf with incorrect signers
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeInvalidSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.expectRevert("GS013");
        execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

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
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);

        // Set keyperhelper gnosis safe to org
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function from a not authorized caller
        // vm.startPrank(rootAddr);
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
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);

        // Set keyperhelper gnosis safe to org
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
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
        vm.stopBroadcast();
    }

    // // Revert InvalidGnosisSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE, SAFE_LEAD
    // // TargerSafe: fakeTargetSafe
    // // TargetSafe Type: EOA
    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(safeSquadA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller

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
        vm.stopBroadcast();
    }
}
