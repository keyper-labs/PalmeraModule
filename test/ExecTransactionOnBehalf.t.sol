// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

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
    //           safeA1 <--------
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree(
    ) public {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
            safeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree_2_levels(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Set palmerahelper safe to org

        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        safeHelper.updateSafeInterface(rootAddr);
        bool result = safeHelper.execTransactionOnBehalfTx(
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
    }

    // ! ********************** SAFE_LEAD ROLE ********************

    // Caller Info: SAFE_LEAD(role), SAFE(type), safeB(hierachie)
    // TargerSafe: safeSubSubSafeA1
    // TargetSafe Type: safe (not a child)
    //            rootSafe
    //           |        |
    //  safeA1       safeB
    //      |
    // safeSubSafeA1
    //      |
    // safeSubSubSafeA1
    function testCan_ExecTransactionOnBehalf_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD()
        public
    {
        (uint256 rootId,, uint256 safeBId,, uint256 safeSubSubSafeA1Id) =
        palmeraSafeBuilder.setUpBaseOrgTree(
            orgName, safeA1Name, safeBName, subSafeA1Name, subSubSafeA1Name
        );
        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeBAddr = palmeraModule.getSafeAddress(safeBId);
        address safeSubSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSubSafeA1Id);

        vm.deal(safeSubSubSafeA1Addr, 100 gwei);
        vm.deal(safeBAddr, 100 gwei);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeBAddr, safeSubSubSafeA1Id, true
        );
        vm.stopPrank();
        // Verify if the safeBAddr have the role of Safe Lead to execute, executionTransactionOnBehalf
        assertEq(palmeraModule.isSuperSafe(safeBId, safeSubSubSafeA1Id), false);
        palmeraHelper.setSafe(safeBAddr);

        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeBAddr,
            safeSubSubSafeA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        bool result = safeHelper.execTransactionOnBehalfTx(
            orgHash,
            safeBAddr,
            safeSubSubSafeA1Addr,
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
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id, uint256[] memory ownersPK,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        Safe rootSafe = Safe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        uint256 threshold = rootSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j; j < threshold; ++j) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Inverse_WAY(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id, uint256[] memory ownersPK,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        Safe rootSafe = Safe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        uint256 threshold = rootSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 i; i < threshold; ++i) {
            uint256 j = threshold - 1 - i; // reverse order
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Root Safe sign args
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(callerEOA);
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
    }

    // // ! ********************** SUPER_SAFE ROLE ********************

    // // execTransactionOnBehalf
    // // Caller: safeA1
    // // Caller Type: safe
    // // Caller Role: SUPER_SAFE of safeSubSafeA1
    // // TargerSafe: safeSubSafeA1
    // // TargetSafe Type: safe
    // //            rootSafe
    // //               |
    // //           safeA1 as superSafe ---
    // //              |                        |
    // //           safeSubSafeA1 <------------
    function testCan_ExecTransactionOnBehalf_SUPER_SAFE_as_SAFE_is_TARGETS_LEAD_SameTree(
    ) public {
        (, uint256 safeA1Id, uint256 safeSubSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeA1Addr = palmeraModule.getSafeAddress(safeA1Id);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        // Send ETH to safe&subsafe
        vm.deal(safeA1Addr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Set palmerahelper safe to safeA1
        palmeraHelper.setSafe(safeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
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
        safeHelper.updateSafeInterface(safeA1Addr);
        bool result = safeHelper.execTransactionOnBehalfTx(
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
    }

    // execTransactionOnBehalf when is Any EOA, passing the signature of owners of the Super Safe of Target Safe
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: nothing
    // Caller Role: SUPER_SAFE of safeSubSafeA1
    // SuperSafe: safeA1Name
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //           safeA1 ---------
    //              |                 |
    //           safeSubSafeA1 <-----
    function testCan_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way_from_superSafe(
    ) public {
        (
            ,
            uint256 safeA1NId,
            uint256 safeSubSafeA1Id,
            ,
            uint256[] memory ownersSuperPK
        ) = palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address safeA1NAddr = palmeraModule.getSafeAddress(safeA1NId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(safeA1NAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from safeA1NAddr
        Safe superSafe = Safe(payable(safeA1NAddr));

        // get owners of the root safe
        address[] memory owners = superSafe.getOwners();
        uint256 threshold = superSafe.getThreshold();
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j; j < threshold; ++j) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                safeA1NAddr,
                safeSubSafeA1Addr,
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
            safeA1NAddr,
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_WRONG_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Target Safe signed args and of Root/Super Safe
        palmeraHelper.setSafe(safeSubSafeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_INVALID_SIGNATURES(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Owner of Root Safe sign args
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        // use invalid signatures
        bytes memory signatures = palmeraHelper.encodeInvalidSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Straight_way_incomplete(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id, uint256[] memory ownersPK,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        Safe rootSafe = Safe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        // reduce threshold by 1, and use incomplete signatures
        uint256 threshold = rootSafe.getThreshold() - 1;
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 j; j < threshold; ++j) {
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
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
    // TargerSafe: safeSubSafeA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeA1          |
    //              |                 |
    //           safeSubSafeA1 <-----
    function testRevert_ExecTransactionOnBehalf_as_EOA_is_NOT_ROLE_with_RIGHTS_SIGNATURES_signed_one_by_one_Inverse_WAY_incomplete(
    ) public {
        (uint256 rootId,, uint256 safeSubSafeA1Id, uint256[] memory ownersPK,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeSubSafeA1Addr =
            palmeraModule.getSafeAddress(safeSubSafeA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubSafeA1Addr, 100 gwei);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // get safe from rootAddr
        Safe rootSafe = Safe(payable(rootAddr));

        // get owners of the root safe
        address[] memory owners = rootSafe.getOwners();
        // reduce threshold by 1, and use incomplete signatures
        uint256 threshold = rootSafe.getThreshold() - 1;
        uint256 nonce = palmeraModule.nonce();

        // Init Valid Owners
        initValidOnwers(4);

        bytes memory concatenatedSignatures;
        bytes memory emptyData;

        for (uint256 i; i < threshold; ++i) {
            uint256 j = threshold - 1 - i; // reverse order
            address currentOwner = owners[j];
            vm.startPrank(currentOwner);
            bytes memory palmeraTxHashData = palmeraModule.encodeTransactionData(
                orgHash,
                rootAddr,
                safeSubSafeA1Addr,
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
            safeSubSafeA1Addr,
            receiver,
            26 gwei,
            emptyData,
            Enum.Operation(0),
            concatenatedSignatures
        );
        vm.stopPrank();
    }

    // // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubSafeA1 is attempting to execute on its superSafe)
    // // Caller: safeSubSafeA1
    // // Caller Type: safe
    // // Caller Role: SUPER_SAFE
    // // TargerSafe: safeA1
    // // TargetSafe Type: safe as lead
    // //   rootSafe
    // //      |
    // //  safeA1 <----
    // //      |            |
    // // safeSubSafeA1 ---
    // //      |
    // // safeSubSubSafeA1
    function testRevertSuperSafeExecOnBehalf() public {
        (uint256 rootId, uint256 safeIdA1, uint256 subSafeIdA1,) =
        palmeraSafeBuilder.setupOrgFourTiersTree(
            orgName, safeA1Name, subSafeA1Name, subSubSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address safeSubSafeA1Addr = palmeraModule.getSafeAddress(subSafeIdA1);

        // Send ETH to org&subsafe
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeA1Addr, 100 gwei);

        // Set palmerahelper safe to safeSubSafeA1
        palmeraHelper.setSafe(safeSubSafeA1Addr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            safeSubSafeA1Addr,
            safeA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(safeSubSafeA1Addr);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        bool result = palmeraModule.execTransactionOnBehalf(
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
    }

    // Revert "GS013" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        palmeraHelper.setSafe(rootAddr);

        // Try onbehalf with incorrect signers
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeInvalidSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
            safeA1Addr,
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
    // // TargerSafe: safeA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        // Fake receiver = Zero address
        address fakeReceiver = address(0);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
            safeA1Addr,
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
    // // TargerSafe: safeA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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

    // // Revert ZeroAddressProvided() execTransactionOnBehalf when param "org" is bytes32(0)
    // // Scenario 3
    // // Caller: rootAddr (org)
    // // Caller Type: rootSafe
    // // Caller Role: ROOT_SAFE
    // // TargerSafe: safeA1
    // // TargetSafe Type: safe as a Child
    // //            rootSafe -----------
    // //               |                |
    // //           safeA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
            safeA1Addr,
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
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        address fakeTargetSafe = address(0xFFE);

        // Set palmerahelper safe to org
        palmeraHelper.setSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            rootAddr,
            safeA1Addr,
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
    //    Safe A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
    // TODO: test this scenario in Live Testnet
    function testCannot_ExecTransactionOnBehalf_Wrapper_ExecTransactionOnBehalf_ChildSafe_over_RootSafe_With_SAFE(
    ) public {
        (uint256 rootId, uint256 safeA1, uint256 childSafeA1,,) =
        palmeraSafeBuilder.setupOrgThreeTiersTree(
            orgName, safeA1Name, subSafeA1Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        address childSafeA1Addr = palmeraModule.getSafeAddress(childSafeA1);

        // Send ETH to safe&subsafe
        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeA1Addr, 100 gwei);
        vm.deal(childSafeA1Addr, 100 gwei);

        // Create a child safe for safe A2
        address fakeCaller = safeHelper.newPalmeraSafe(4, 2);
        bool result = safeHelper.createAddSafeTx(safeA1, "ChildSafeA2");
        assertEq(result, true);

        // Set Safe Role in Safe A1 over Child Safe A1
        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
            fakeCaller,
            childSafeA1,
            true
        );
        assertTrue(palmeraModule.isSafeLead(childSafeA1, fakeCaller));
        vm.stopPrank();

        // Set palmerahelper safe to fakeCaller
        palmeraHelper.setSafe(fakeCaller);
        bytes memory emptyData;
        bytes memory signatures = palmeraHelper.encodeSignaturesPalmeraTx(
            orgHash,
            fakeCaller,
            childSafeA1Addr,
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

        // Execute on behalf function from a not authorized caller (Root Safe of Another Tree) over Super Safe and Safe Safe in another Three
        safeHelper.updateSafeInterface(fakeCaller);
        result = safeHelper.execTransactionOnBehalfTx(
            orgHash,
            fakeCaller,
            childSafeA1Addr,
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
        Attacker attackerContract =
            new Attacker(payable(address(palmeraModule)));
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
