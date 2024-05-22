// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/SigningUtils.sol";
import "../test/helpers/SkipSetupEnv.s.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title Several Scenarios of Execution On Behalf in live Mainnet/Testnet (Polygon and Sepolia)
/// @custom:security-contact general@palmeradao.xyz
contract SkipSeveralScenarios is Script, SkipSetupEnv {
    /// Setup the Environment, with run() from SkipSetupEnvGoerli
    function setUp() public {
        // Set up env
        run();
        testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSafe_over_RootSafe_With_SAFE(
        );
        // These are different chain test scenarios, specifically for the execTransactionOnBehalf function in Polygon and Sepolia.
        // We test each scenario independently manually and get the results on the Live Mainnet on Polygon and Sepolia.
        // testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSafe_over_RootSafe_With_SAFE(); // ✅
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
    // Previously, Create a Org, Root Safe and Safe A1 Safe
    // and them will send ETH from the safe safe A1 to the receiver
    function TestExecutionOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address payable rootAddr = payable(palmeraModule.getSafeAddress(rootId));
        address payable safeA1Addr =
            payable(palmeraModule.getSafeAddress(safeA1));
        address payable receiverAddr = payable(receiver);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = receiverAddr.call{value: 1e5 gwei}("");
        require(sent, "Failed to send Ether");

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        bool result = execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
    //    Safe A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSafe_over_RootSafe_With_SAFE(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(org2Name, safeA2Name);

        address payable rootAddr = payable(palmeraModule.getSafeAddress(rootId));
        address payable safeA1Addr =
            payable(palmeraModule.getSafeAddress(safeA1));
        address childSafeA1Addr = newPalmeraSafe(4, 2);
        setSafe(safeA1Addr);
        bool result = createAddSafeTx(safeA1, "ChildSafeA1");
        assertEq(result, true);
        orgHash = palmeraModule.getOrgBySafe(rootId);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = rootAddr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = childSafeA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");

        console.log("Child Safe A1 address: ", childSafeA1Addr);

        address fakeCaller = newPalmeraSafe(4, 2);

        // Set palmerahelper safe to Super Safe A1
        setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            safeA1Addr,
            childSafeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Set palmerahelper safe to Faker Caller
        setSafe(fakeCaller);
        bytes memory signatures2 = encodeSignaturesPalmeraTx(
            orgHash,
            fakeCaller,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );
        /// Wrapper of Execution On Behalf, for  try to avoid the verification in the Safe / Palmera Module
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            childSafeA1Addr,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a authorized caller (Super Safe of These Tree) over child Safes but internal a Wrapper executeOnBehalf over Root Safe
        setSafe(safeA1Addr);
        result = execTransactionOnBehalfTx(
            orgHash,
            childSafeA1Addr,
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
    //    Safe A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSafe_over_RootSafe_With_EOA(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe("org5Name", "safeA1Name");

        address payable rootAddr = payable(palmeraModule.getSafeAddress(rootId));
        address childSafeA1Addr = newPalmeraSafe(4, 2);
        bool result = createAddSafeTx(safeA1, "ChildSafeA1");
        assertEq(result, true);
        orgHash = palmeraModule.getOrgBySafe(rootId);
        uint256 childSafeA1 =
            palmeraModule.getSafeIdBySafe(orgHash, childSafeA1Addr);

        // Create a fakeCaller with Ramdom EOA
        address fakeCaller = address(msg.sender);
        (bool sent, bytes memory data) =
            childSafeA1Addr.call{value: 5e5 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = rootAddr.call{value: 5e5 gwei}("");
        require(sent, "Failed to send Ether");

        // Set Safe Role in FakeCaller (msg.sender) over Child Safe A1
        setSafe(rootAddr);
        result = createSetRoleTx(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            fakeCaller,
            childSafeA1,
            true
        );
        assertEq(result, true);
        assertEq(palmeraModule.isSafeLead(childSafeA1, fakeCaller), true);

        // Value to be sent to the receiver with rightCaller
        bytes memory emptyData;
        bytes memory signatures;

        // Set palmerahelper safe to rootAddr
        setSafe(childSafeA1Addr);
        // Try to execute on behalf function from a not authorized caller child Safe A1 over Root Safe
        bytes memory signatures2 = encodeSignaturesPalmeraTx(
            orgHash,
            childSafeA1Addr,
            rootAddr,
            receiver,
            57 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // ttry to encode the end of the signature, from EOA random the internal data to the Wrapper of
        // Execution On Behalf, with a rogue caller and that is secondary safe A1 over Root Safe
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            childSafeA1Addr,
            rootAddr,
            receiver,
            57 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Safe in another Three
        result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            childSafeA1Addr,
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
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Receiver address Test Execution On Behalf: ", receiver);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);

        // tx ETH from msg.sender to safeA1Addr
        (bool sent, bytes memory data) = safeA1Addr.call{value: 2 gwei}("");
        require(sent, "Failed to send Ether");

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        bool result = execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES(
    ) public {
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSafeA1Id) =
            setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSafeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(msg.sender);

        // Owner of Root Safe sign args
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
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
    // Caller: safeA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE of safeSubSafeA1
    // TargerSafe: safeSubSafeA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeA1 as superSafe ---
    //              |                        |
    //           safeSubSafeA1 <------------
    function testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree(
    ) public {
        vm.startBroadcast();
        (, uint256 safeA1Id, uint256 safeSubSafeA1Id) =
            setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = safeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSafeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Set palmerahelper safe to safeA1
        setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            safeA1Addr,
            safeSubSafeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        /// Verify if the safeA1Addr have the role to execute, executionTransactionOnBehalf
        assertEq(
            palmeraRolesContract.doesUserHaveRole(
                safeA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );

        // Execute on safe tx
        setSafe(safeA1Addr);
        bool result = execTransactionOnBehalfTx(
            orgHash,
            safeA1Addr,
            safeSubSafeA1Addr,
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

    // Revert: "GS020" execTransactionOnBehalf when is Any EOA, passing the wrong signature of the Root/Super Safe of Target Safe
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // SuperSafe: rootAddr
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_WRONG_SIGNATURES(
    ) public {
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSafeA1Id) =
            setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSafeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(msg.sender);

        // Owner of Target Safe signed args
        setSafe(safeSubSafeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // GS020: Signatures data too short
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Revert: "GS026" execTransactionOnBehalf when is Any EOA, (invalid signatures provided)
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // SuperSafe: rootAddr
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_INVALID_SIGNATURES(
    ) public {
        vm.startBroadcast();
        (uint256 rootId,, uint256 safeSubSafeA1Id) =
            setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeSubSafeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        // Random wallet instead of a safe (EOA)
        address callerEOA = address(msg.sender);

        // Owner of Root Safe sign args
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeInvalidSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // GS026: Invalid owner provided
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSafeA1 is attempting to execute on its superSafe)
    // Caller: safeSubSafeA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe as lead
    //            rootSafe
    //           |
    //  safeA1 <----
    //      |            |
    // safeSubSafeA1 ---
    //      |
    // safeSubSubSafeA1
    function testRevertSuperSafeExecOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeIdA1, uint256 subSafeIdA1) =
            setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address safeSubSafeA1Addr = palmeraModule.getSafeAddress(subSafeIdA1);

        // Send ETH to org&subsafe
        // tx ETH from msg.sender to rootAddr
        (bool sent, bytes memory data) = rootAddr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");
        (sent, data) = safeA1Addr.call{value: 100 gwei}("");
        require(sent, "Failed to send Ether");

        // Set palmerahelper safe to safeSubSafeA1
        setSafe(safeSubSafeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            safeSubSafeA1Addr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        setSafe(safeSubSafeA1Addr);
        // NotAuthorizedExecOnBehalf: Caller is not authorized to execute on behalf
        bool result = execTransactionOnBehalfTx(
            orgHash,
            safeSubSafeA1Addr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
        vm.stopBroadcast();
    }

    // Revert "GS026" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);

        // Try onbehalf with incorrect signers
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeInvalidSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // GS026/GS013: Invalid owner provided
        execTransactionOnBehalfTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when arg "to" is address(0)
    // Scenario 1
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);
        address fakeReceiver = address(0);

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // InvalidAddressProvided: Invalid address provided
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeA1Addr,
            fakeReceiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "targetSafe" is address(0)
    // Scenario 2
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // InvalidSafe: Invalid Safe
        palmeraModule.execTransactionOnBehalf(
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

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "org" is address(0)
    // Scenario 3
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // OrgNotRegistered: Org not registered
        palmeraModule.execTransactionOnBehalf(
            bytes32(0),
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }

    // Revert InvalidSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SAFE_LEAD
    // TargerSafe: fakeTargetSafe
    // TargetSafe Type: EOA
    function testRevertInvalidSafeExecTransactionOnBehalf() public {
        vm.startBroadcast();
        (uint256 rootId, uint256 safeA1) =
            setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        console.log("Root address Test Execution On Behalf: ", rootAddr);
        console.log("Safe A1 Test Execution On Behalf: ", safeA1Addr);
        address fakeTargetSafe = address(0xFFE);

        // Set palmerahelper safe to org
        setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // InvalidSafe: Invalid Safe
        palmeraModule.execTransactionOnBehalf(
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
