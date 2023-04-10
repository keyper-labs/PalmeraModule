// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/SigningUtils.sol";
import "../test/helpers/SkipSetupEnvGoerli.s.sol";

contract SkipSeveralScenariosGoerli is Script, SkipSetupEnvGoerli {
    /// Setup the Environment, with run() from SkipSetupEnvGoerli
    function setUp() public {
        // Set up env
        run();
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
        gnosisSafe = GnosisSafe(payable(rootAddr));
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
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
        address childSquadA1Addr = newPalmeraSafe(4, 2);
        bool result = createAddSquadTx(safeSquadA1, "ChildSquadA1");
        assertEq(result, true);
        orgHash = keyperModule.getOrgBySquad(rootId);

        // Create a child safe for squad A2
        address fakeCaller = newPalmeraSafe(4, 2);
        result = createAddSquadTx(safeSquadA1, "ChildSquadA2");
        assertEq(result, true);

        // Set keyperhelper gnosis safe to Super Safe Squad A1
        gnosisSafe = GnosisSafe(payable(safeSquadA1Addr));
        bytes memory emptyData;
        bytes memory signatures = encodeSignaturesPalmeraTx(
            safeSquadA1Addr,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Set keyperhelper gnosis safe to Faker Caller
        gnosisSafe = GnosisSafe(payable(fakeCaller));
        bytes memory signatures2 = encodeSignaturesPalmeraTx(
            fakeCaller,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );
        /// Wrapper of Execution On Behalf, for  try to avoid the verification in the Gnosis Safe / Palmera Module
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

        // Execute on behalf function from a authorized caller (Super Safe of These Tree) over child Squads but internal a Wrapper executeOnBehalf over Root Safe
        gnosisSafe = GnosisSafe(payable(safeSquadA1Addr));
        result = execTransactionOnBehalfTx(
            orgHash,
            childSquadA1Addr,
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
        address childSquadA1Addr = newPalmeraSafe(4, 2);
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
        gnosisSafe = GnosisSafe(rootAddr);
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
        gnosisSafe = GnosisSafe(payable(childSquadA1Addr));
        bytes memory signatures2 = encodeSignaturesPalmeraTx(
            childSquadA1Addr,
            rootAddr,
            receiver,
            57 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
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
            receiver,
            2 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        vm.stopBroadcast();
    }
}
