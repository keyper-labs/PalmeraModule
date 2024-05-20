// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "./helpers/SignersHelper.t.sol";
import "./helpers/ReentrancyAttackHelper.t.sol";
import "./helpers/DeployHelper.t.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";

/// @title ExecTransactionOnBehalf
/// @custom:security-contact general@palmeradao.xyz
contract ExecTransactionOnBehalf is DeployHelper, SignersHelper {
    using ECDSA for bytes32;

    function setUp() public {
        DeployHelper.deployAllContracts(60);
    }

    // ! ********************** ROOT_SAFE ROLE ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    //            rootSafe -----------
    //               |                |
    //           safeSquadA1 <--------
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
    ) public {
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function

        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.execTransactionOnBehalfTx(
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
        (uint256 rootId,, uint256 safeSubSquadA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Set palmerahelper safe to org

        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.execTransactionOnBehalfTx(
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
        palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, squadA1Name, squadBName, subSquadA1Name, subSubSquadA1Name
        );
        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadBAddr = palmeraModule.getSquadSafeAddress(safeSquadBId);
        address safeSubSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSubSquadA1Id);

        vm.deal(safeSubSubSquadA1Addr, 100 gwei);
        vm.deal(safeSquadBAddr, 100 gwei);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeSquadBAddr, safeSubSubSquadA1Id, true
        );
        vm.stopPrank();
        // Verify if the safeSquadBAddr have the role of Safe Lead to execute, executionTransactionOnBehalf
        assertEq(
            palmeraModule.isSuperSafe(safeSquadBId, safeSubSubSquadA1Id), false
        );
        palmeraHelper.setSafe(safeSquadBAddr);

        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeSquadBAddr,
            safeSubSubSquadA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        bool result = safeHelper.execTransactionOnBehalfTx(
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
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        palmeraHelper.setSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Set safe_lead role to fake caller
        vm.startPrank(rootAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, callerEOA, rootId, true);
        vm.stopPrank();

        // Verify if the callerEOA have the role of Safe Lead to execute, executionTransactionOnBehalf
        assertEq(palmeraModule.isSafeLead(rootId, callerEOA), true);
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(callerEOA);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            rootAddr,
            receiver,
            22 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 22 gwei);
        vm.stopPrank();
    }

    // execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Root/Super Safe of Target Safe
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
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id, uint256[] memory ownersPK,)
        = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        GnosisSafe rootSafe = GnosisSafe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        uint256 threshold = rootSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j = 0; j < threshold; j++) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSquadA1Addr,
                receiver,
                37 gwei,
                emptyData,
                Enum.Operation(0),
                nonce
            );
            bytes32 digest = keccak256(palmeraTxHashData);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownersPK[j], digest);
            // verify signer
            address signer = ecrecover(digest, v, r, s);
            assertEq(signer, currentOwner);
            bytes memory signature = abi.encodePacked(r, s, v);
            concatenatedSignatures =
                abi.encodePacked(concatenatedSignatures, signature);
            vm.stopPrank();
        }
        // verify signature length
        assertEq(concatenatedSignatures.length, threshold * 65);

        vm.startPrank(callerEOA);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            37 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 37 gwei);
        vm.stopPrank();
    }

    // execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Root/Super Safe of Target Safe
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
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Inverse_WAY(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id, uint256[] memory ownersPK,)
        = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        GnosisSafe rootSafe = GnosisSafe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        uint256 threshold = rootSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 i = 0; i < threshold; i++) {
            uint256 j = threshold - 1 - i; // reverse order
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSquadA1Addr,
                receiver,
                26 gwei,
                emptyData,
                Enum.Operation(0),
                nonce
            );
            bytes32 digest = keccak256(palmeraTxHashData);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownersPK[j], digest);
            // verify signer
            address signer = ecrecover(digest, v, r, s);
            assertEq(signer, currentOwner);
            bytes memory signature = abi.encodePacked(r, s, v);
            concatenatedSignatures =
                abi.encodePacked(concatenatedSignatures, signature);
            vm.stopPrank();
        }
        // verify signature length
        assertEq(concatenatedSignatures.length, threshold * 65);

        vm.startPrank(callerEOA);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            26 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 26 gwei);
        vm.stopPrank();
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
        (uint256 rootId,, uint256 safeSubSquadA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Root Safe sign args
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(callerEOA);
        bool result = palmeraModule.execTransactionOnBehalf(
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
        (, uint256 safeSquadA1Id, uint256 safeSubSquadA1Id,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address safeSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSquadA1Id);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        // Send ETH to squad&subsquad
        vm.deal(safeSquadA1Addr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Set palmerahelper safe to safeSquadA1
        palmeraHelper.setSafe(safeSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
            palmeraRolesContract.doesUserHaveRole(
                safeSquadA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );

        // Execute on safe tx
        safeHelper.updateSafeInterface(safeSquadA1Addr);
        bool result = safeHelper.execTransactionOnBehalfTx(
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

    // execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Super Safe of Target Safe
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // Caller Role: SUPER_SAFE of safeSubSquadA1
    // SuperSafe: squadA1Name
    // TargerSafe: safeSubSquadA1, same hierachical tree with 2 levels diff
    //           safeSquadA1 ---------
    //              |                 |
    //           safeSubSquadA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way_from_superSafe(
    ) public {
        (
            ,
            uint256 squadA1NId,
            uint256 safeSubSquadA1Id,
            ,
            uint256[] memory ownersSuperPK
        ) = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address squadA1NAddr = palmeraModule.getSquadSafeAddress(squadA1NId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(squadA1NAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from squadA1NAddr
        GnosisSafe superSafe = GnosisSafe(payable(squadA1NAddr));

        // get owners of the root safe
        address[] memory owners = superSafe.getOwners();
        uint256 threshold = superSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j = 0; j < threshold; j++) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                squadA1NAddr,
                safeSubSquadA1Addr,
                receiver,
                39 gwei,
                emptyData,
                Enum.Operation(0),
                nonce
            );
            bytes32 digest = keccak256(palmeraTxHashData);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownersSuperPK[j], digest);
            // verify signer
            address signer = ecrecover(digest, v, r, s);
            assertEq(signer, currentOwner);
            bytes memory signature = abi.encodePacked(r, s, v);
            concatenatedSignatures =
                abi.encodePacked(concatenatedSignatures, signature);
            vm.stopPrank();
        }
        // verify signature length
        assertEq(concatenatedSignatures.length, threshold * 65);

        vm.startPrank(callerEOA);
        bool result = palmeraModule.execTransactionOnBehalf(
            orgHash,
            squadA1NAddr,
            safeSubSquadA1Addr,
            receiver,
            39 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 39 gwei);
        vm.stopPrank();
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
        (uint256 rootId,, uint256 safeSubSquadA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Target Safe signed args and of Root/Super Safe
        palmeraHelper.setSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
        palmeraModule.execTransactionOnBehalf(
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
        (uint256 rootId,, uint256 safeSubSquadA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Root Safe sign args
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        // use invalid signatures
        bytes memory signatures = palmeraHelper.encodeInvalidSignaturesPalmeraTx(
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
        palmeraModule.execTransactionOnBehalf(
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

    // Revert: GS020 (Signatures data too short), execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Root/Super Safe of Target Safe Incomplete
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
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way_incomplete(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id, uint256[] memory ownersPK,)
        = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        GnosisSafe rootSafe = GnosisSafe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        // reduce threshold by 1, and use incomplete signatures
        uint256 threshold = rootSafe.getThreshold() - 1;
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j = 0; j < threshold; j++) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSquadA1Addr,
                receiver,
                37 gwei,
                emptyData,
                Enum.Operation(0),
                nonce
            );
            bytes32 digest = keccak256(palmeraTxHashData);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownersPK[j], digest);
            // verify signer
            address signer = ecrecover(digest, v, r, s);
            assertEq(signer, currentOwner);
            bytes memory signature = abi.encodePacked(r, s, v);
            concatenatedSignatures =
                abi.encodePacked(concatenatedSignatures, signature);
            vm.stopPrank();
        }
        // verify signature length
        assertEq(concatenatedSignatures.length, threshold * 65);

        vm.startPrank(callerEOA);
        vm.expectRevert("GS020");
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            37 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        vm.stopPrank();
    }

    // Revert: GS020 (Signatures data too short), execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Root/Super Safe of Target Safe Incomplete
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
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Inverse_WAY_incomplete(
    ) public {
        (uint256 rootId,, uint256 safeSubSquadA1Id, uint256[] memory ownersPK,)
        = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(safeSubSquadA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSquadA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        GnosisSafe rootSafe = GnosisSafe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        // reduce threshold by 1, and use incomplete signatures
        uint256 threshold = rootSafe.getThreshold() - 1;
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 i = 0; i < threshold; i++) {
            uint256 j = threshold - 1 - i; // reverse order
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSquadA1Addr,
                receiver,
                26 gwei,
                emptyData,
                Enum.Operation(0),
                nonce
            );
            bytes32 digest = keccak256(palmeraTxHashData);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownersPK[j], digest);
            // verify signer
            address signer = ecrecover(digest, v, r, s);
            assertEq(signer, currentOwner);
            bytes memory signature = abi.encodePacked(r, s, v);
            concatenatedSignatures =
                abi.encodePacked(concatenatedSignatures, signature);
            vm.stopPrank();
        }
        // verify signature length
        assertEq(concatenatedSignatures.length, threshold * 65);

        vm.startPrank(callerEOA);
        vm.expectRevert("GS020");
        palmeraModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
            safeSubSquadA1Addr,
            receiver,
            26 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        vm.stopPrank();
    }

    // // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSquadA1 is attempting to execute on its superSafe)
    // // Caller: safeSubSquadA1
    // // Caller Type: safe
    // // Caller Role: SUPER_SAFE
    // // TargerSafe: safeSquadA1
    // // TargetSafe Type: safe as lead
    // //   rootSafe
    // //      |
    // //  safeSquadA1 <----
    // //      |            |
    // // safeSubSquadA1 ---
    // //      |
    // // safeSubSubSquadA1
    function testRevertSuperSafeExecOnBehalf() public {
        (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1,) =
        palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, squadA1Name, subSquadA1Name, subSubSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(squadIdA1);
        address safeSubSquadA1Addr =
            palmeraModule.getSquadSafeAddress(subSquadIdA1);

        // Send ETH to org&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSquadA1Addr, 100 gwei);

        // Set palmerahelper safe to safeSubSquadA1
        palmeraHelper.setSafe(safeSubSquadA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
        bool result = palmeraModule.execTransactionOnBehalf(
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
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);
        palmeraHelper.setSafe(rootAddr);

        // Try onbehalf with incorrect signers
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeInvalidSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        safeHelper.updateSafeInterface(rootAddr);
        vm.expectRevert("GS013");
        // Execute invalid OnBehalf function
        safeHelper.execTransactionOnBehalfTx(
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
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);
        // Fake receiver = Zero address
        address fakeReceiver = address(0);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
        palmeraModule.execTransactionOnBehalf(
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
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
            abi.encodeWithSelector(Errors.InvalidSafe.selector, address(0))
        );
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
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
        palmeraModule.execTransactionOnBehalf(
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

    // // Revert InvalidSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE, SAFE_LEAD
    // // TargerSafe: fakeTargetSafe
    // // TargetSafe Type: EOA
    function testRevertInvalidSafeExecTransactionOnBehalf() public {
        (uint256 rootId, uint256 safeSquadA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);
        address fakeTargetSafe = address(0xFFE);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
            abi.encodeWithSelector(Errors.InvalidSafe.selector, fakeTargetSafe)
        );
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
    }

    // Org with a root safe with 3 child levels: A, B, C
    //    Squad A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSquad_over_RootSafe_With_SAFE(
    ) public {
        (uint256 rootId, uint256 safeSquadA1, uint256 childSquadA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, squadA1Name, subSquadA1Name
        );

        address rootAddr = palmeraModule.getSquadSafeAddress(rootId);
        address safeSquadA1Addr = palmeraModule.getSquadSafeAddress(safeSquadA1);
        address childSquadA1Addr =
            palmeraModule.getSquadSafeAddress(childSquadA1);

        // Send ETH to squad&subsquad
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSquadA1Addr, 100 gwei);
        vm.deal(childSquadA1Addr, 100 gwei);

        // Create a child safe for squad A2
        address fakeCaller = safeHelper.newPalmeraSafe(4, 2);
        bool result = safeHelper.createAddSquadTx(safeSquadA1, "ChildSquadA2");
        assertEq(result, true);

        // Set Safe Role in Safe Squad A1 over Child Squad A1
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childSquadA1,
            true
        );
        assertTrue(palmeraModule.isSafeLead(childSquadA1, fakeCaller));
        vm.stopPrank();

        // Set palmerahelper safe to fakeCaller
        palmeraHelper.setSafe(fakeCaller);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            fakeCaller,
            childSquadA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes memory signatures2 = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(fakeCaller);
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            orgHash,
            rootAddr,
            rootAddr,
            receiver,
            100 gwei,
            emptyData,
            Enum.Operation(0),
            signatures2
        );
        vm.stopPrank();

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Squad Safe in another Three
        safeHelper.updateSafeInterface(fakeCaller);
        result = safeHelper.execTransactionOnBehalfTx(
            orgHash,
            fakeCaller,
            childSquadA1Addr,
            receiver,
            2 gwei,
            internalData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei); // indirect verification, because the receiver is 2 gwei and not 102 gwei
    }

    // // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(palmeraModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            palmeraModule, attackerContract, safeHelper, 30
        );

        (bytes32 orgName, address orgAddr, address attacker, address victim) =
            attackerHelper.setAttackerTree(orgName);

        safeHelper.updateSafeInterface(victim);
        attackerContract.setOwners(safeHelper.safeWallet().getOwners());

        safeHelper.updateSafeInterface(attacker);
        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper
            .encodeSignaturesForAttackPalmeraTx(
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
