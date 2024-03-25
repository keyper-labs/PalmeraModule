// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/SigningUtils.sol";
import "../test/helpers/SkipSetupEnv.s.sol";
import {Errors} from "../libraries/Errors.sol";

contract SkipSeveralScenarios is Script, SkipSetupEnv {
    /// Setup the Environment, with run() from SkipSetupEnvGoerli
    function setUp() public {
        // Set up env
        run();
        TestExecutionOnBehalf(); // ✅
            // testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_SAFE(); // ✅
            // testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_EOA(); // ???
            // testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(); // ✅
            // testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES(); // ✅
            // testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree(); // ✅
            // testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_WRONG_SIGNATURES(); // ✅
            // testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_INVALID_SIGNATURES(); // ✅
            // testRevertInvalidSignatureExecOnBehalf(); // ✅
            // testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(); // ✅
            // testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo(); // ✅
            // testRevertSuperSafeExecOnBehalf(); // ✅
    }

    // Test Execution On Behalf
    // This test is to check if the execution on behalf is working correctly
    // Previously, Create a Org, Root Safe and Squad A1 Safe
    // and them will send ETH from the safe squad A1 to the receiver
    function TestExecutionOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(orgName, squadA1Name);

        address payable rootAddr =
            payable(keyperModule.getSquadSafeAddress(rootId));
        address payable safeSquadA1Addr =
            payable(keyperModule.getSquadSafeAddress(safeSquadA1));
        address payable receiverAddr = payable(receiver);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe Squad A1 Test Execution On Behalf: ", safeSquadA1Addr);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeSquadA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = receiverAddr.call{value: 1e5 gwei}("");
        require(sent, "Failed to send Ether");

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
        assertEq(receiver.balance, 100002 gwei);
        vm.stopBroadcast();
    }

    // Org with a root safe with 3 child levels: A, B, C
    //    Squad A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_SAFE(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad(org2Name, squadA2Name);

        address payable rootAddr =
            payable(keyperModule.getSquadSafeAddress(rootId));
        address payable safeSquadA1Addr =
            payable(keyperModule.getSquadSafeAddress(safeSquadA1));
        address childSquadA1Addr = newKeyperSafe(4, 2);
        setGnosisSafe(safeSquadA1Addr);
        bool result = createAddSquadTx(safeSquadA1, "ChildSquadA1");
        assertEq(result, true);
        // Create a child safe for squad A2
        // result = createAddSquadTx(safeSquadA1, "ChildSquadA2");
        // assertEq(result, true);
        orgHash = keyperModule.getOrgBySquad(rootId);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeSquadA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = rootAddr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = childSquadA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");

        console.log("Child Squad A1 address: ", childSquadA1Addr);

        address fakeCaller = newKeyperSafe(4, 2);

        // Set keyperhelper gnosis safe to Super Safe Squad A1
        setGnosisSafe(safeSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            safeSquadA1Addr,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Set keyperhelper gnosis safe to Faker Caller
        setGnosisSafe(fakeCaller);
        bytes memory signatures2 = encodeSignaturesKeyperTx(
            orgHash,
            fakeCaller,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );
        /// Wrapper of Execution On Behalf, for  try to avoid the verification in the Gnosis Safe / Keyper Module
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            childSquadA1Addr,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a authorized caller (Super Safe of These Tree) over child Squads but internal a Wrapper executeOnBehalf over Root Safe
        setGnosisSafe(safeSquadA1Addr);
        result = execTransactionOnBehalfTx(
            orgHash,
            childSquadA1Addr,
            rootAddr,
            receiver,
            2 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Org with a root safe with 3 child levels: A, B, C
    //    Squad A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_EOA(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeSquadA1) =
            setupRootOrgAndOneSquad("org5Name", "squadA1Name");

        address payable rootAddr =
            payable(keyperModule.getSquadSafeAddress(rootId));
        address payable safeSquadA1Addr =
            payable(keyperModule.getSquadSafeAddress(safeSquadA1));
        address payable receiverAddr = payable(receiver);
        address childSquadA1Addr = newKeyperSafe(4, 2);
        bool result = createAddSquadTx(safeSquadA1, "ChildSquadA1");
        assertEq(result, true);
        orgHash = keyperModule.getOrgBySquad(rootId);
        uint256 childSquadA1 =
            keyperModule.getSquadIdBySafe(orgHash, childSquadA1Addr);

        // Create a fakeCaller with Ramdom EOA
        address fakeCaller = address(msg.sender);
        (bool sent, bytes memory data) =
            childSquadA1Addr.call{value: 5e5 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = rootAddr.call{value: 5e5 gwei}("");
        require(sent, "Failed to send Ether");

        // Set Safe Role in FakeCaller (msg.sender) over Child Squad A1
        setGnosisSafe(rootAddr);
        result = createSetRoleTx(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            fakeCaller,
            childSquadA1,
            true
        );
        assertEq(result, true);
        assertEq(keyperModule.isSafeLead(childSquadA1, fakeCaller), true);

        // Value to be sent to the receiver with rightCaller
        bytes memory emptyData;
        bytes memory signatures;

        // Set keyperhelper gnosis safe to rootAddr
        setGnosisSafe(childSquadA1Addr);
        bytes memory signatures2 = encodeSignaturesKeyperTx(
            orgHash,
            childSquadA1Addr,
            rootAddr,
            receiver,
            57 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            childSquadA1Addr,
            rootAddr,
            receiver,
            57 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        result = keyperModule.execTransactionOnBehalf(
            orgHash,
            childSquadA1Addr,
            rootAddr,
            receiver,
            2 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
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
        vm.startBroadcast();
        (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1) =
            setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address safeSubSquadA1Addr =
            keyperModule.getSquadSafeAddress(subSquadIdA1);

        // Send ETH to org&subsquad
        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSquadA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Set keyperhelper gnosis safe to safeSubSquadA1
        setGnosisSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesKeyperTx(
            orgHash,
            safeSubSquadA1Addr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        setGnosisSafe(safeSubSquadA1Addr);
        // vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        bool result = execTransactionOnBehalfTx(
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
        vm.stopBroadcast();
    }

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

        // vm.expectRevert("GS013");
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
