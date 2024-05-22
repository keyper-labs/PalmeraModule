// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/DeployHelper.t.sol";

/// @title ModifySafeOwners
/// @custom:security-contact general@palmeradao.xyz
contract ModifySafeOwners is DeployHelper, SigningUtils {
    function setUp() public {
        DeployHelper.deployAllContracts(90);
    }

    // ! ********************* addOwnerWithThreshold Test ***********************

    // Caller Info: Role-> SAFE_LEAD_MODIFY_OWNERS_ONLY, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> userLeadModifyOwnersOnly
    // Target Info: Name -> safeIdA1, Type -> SAFE, Hierarchy related to caller -> SAFE leading by caller
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            safeIdA1,
            true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(safeA1Addr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold + 1, safeA1Addr, orgHash
        );

        assertEq(safeHelper.safeWallet().getThreshold(), threshold + 1);
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> safe, Name -> safeBAddr
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootIdA, uint256 safeIdA1,, uint256 safeIdB1) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        vm.startPrank(rootAddrA);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            safeBAddr,
            safeIdA1,
            true
        );
        vm.stopPrank();
        assertEq(palmeraModule.isSafeLead(safeIdA1, safeBAddr), true);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        safeHelper.updateSafeInterface(safeBAddr);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, safeAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(safeAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, safeA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> safeAAddr
    // Target Info: Name -> childAAddr, Type -> SAFE,Hierarchy related to caller -> SAME_TREE,CHILDREN
    function testCan_AddOwnerWithThreshold_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 safeIdA1, uint256 childIdA,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);
        address childAAddr = palmeraModule.getSafeAddress(childIdA);

        // Get safeA signers info
        safeHelper.updateSafeInterface(childAAddr);
        address[] memory childA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(childA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        safeHelper.updateSafeInterface(safeAAddr);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, childAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(childAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, childA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAME_TREE,CHILDREN
    function testCan_AddOwnerWithThreshold_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA, uint256 safeIdA1,,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        safeHelper.updateSafeInterface(rootAddrA);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, safeAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(safeAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, safeA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> SUPER, Name -> safeBAddr
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testRevertRootSafeToAttemptTo_AddOwnerWithThreshold_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 safeIdA1,, uint256 safeIdB1,,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            "subSafeB1"
        );

        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        vm.startPrank(safeBAddr);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold, safeAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrB
    // Target Info: Name -> rootAddrB, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testRevertRootSafeToAttemptTo_AddOwnerWithThreshold_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA,, uint256 rootIdB,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);

        // Get safeA signers info
        safeHelper.updateSafeInterface(rootAddrA);
        address[] memory rootAOwners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(rootAOwners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold, rootAddrA, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> safe, Name -> safeA
    // Target Info: Name -> safeB, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD()
        public
    {
        (uint256 rootIdA, uint256 safeIdA1,, uint256 safeIdB1) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        vm.startPrank(rootAddrA);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeBAddr, safeIdA1, true
        );
        vm.stopPrank();
        assertEq(palmeraModule.isSafeLead(safeIdA1, safeBAddr), true);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        safeHelper.updateSafeInterface(safeBAddr);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, safeAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(safeAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, safeA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> safe, Name -> rightCaller
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by rightCaller,
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_as_EOA_is_TARGETS_LEAD()
        public
    {
        (uint256 rootIdA, uint256 safeIdA1,,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address rightCaller = address(0x123);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        vm.startPrank(rootAddrA);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, rightCaller, safeIdA1, true
        );
        vm.stopPrank();
        assertEq(palmeraModule.isSafeLead(safeIdA1, rightCaller), true);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        vm.startPrank(rightCaller);
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold, safeAAddr, orgHash
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(safeAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, safeA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by safeLead,
    function testRevertOwnerAlreadyExistsAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        assertEq(palmeraModule.isSafeLead(rootId, safeLead), true);

        safeHelper.updateSafeInterface(rootAddr);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.OwnerAlreadyExists.selector);
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold + 1, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddr
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertZeroAddressAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);

        safeHelper.updateSafeInterface(rootAddr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.addOwnerWithThreshold(
            zeroAddress, threshold + 1, rootAddr, orgHash
        );

        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        palmeraModule.addOwnerWithThreshold(
            sentinel, threshold + 1, rootAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertInvalidThresholdAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        // (When threshold < 1)
        address newOwner = address(0xf1f1f1);
        uint256 zeroThreshold = 0;

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        palmeraModule.addOwnerWithThreshold(
            newOwner, zeroThreshold, rootAddr, orgHash
        );

        // When threshold > max current threshold
        uint256 wrongThreshold = safeHelper.safeWallet().getOwners().length + 2;

        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        palmeraModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> NONE, Type -> SAFE, Hierarchy -> NOT_REGISTERED, Name -> safeNotRegistered
    // Target Info: Name -> safeNotRegistered, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredAddOwnerWithThreshold_SAFE_Caller()
        public
    {
        address safeNotRegistered = safeHelper.newPalmeraSafe(4, 2);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        address newOwner = safeHelper.newPalmeraSafe(4, 2);

        vm.startPrank(safeNotRegistered);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, safeNotRegistered
            )
        );
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold + 1, safeNotRegistered, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NONE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> InvalidSafeCaller
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredAddOwnerWithThreshold_EOA_Caller()
        public
    {
        safeHelper.newPalmeraSafe(4, 2);
        address InvalidSafeCaller = address(0x123);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        address newOwner = safeHelper.newPalmeraSafe(4, 2);

        vm.startPrank(InvalidSafeCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidSafe.selector, InvalidSafeCaller
            )
        );
        palmeraModule.addOwnerWithThreshold(
            newOwner, threshold + 1, InvalidSafeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NONE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> newOwnerOnOrgA
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> Not Related,
    function testRevertRootSafesAttemptToAddToExternalSafeOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);

        vm.startPrank(rootBAddr);
        palmeraModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, rootAddr, orgHash
        );
        vm.stopPrank();
    }

    // ! ********************* removeOwner Test ***********************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> fakeCaller
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAME_TREE,
    function testRevertZeroAddressProvidedRemoveOwner() public {
        (uint256 rootIdA, uint256 safeIdA1,,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address fakeCaller = palmeraModule.getSafeAddress(rootIdA);

        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = safeA1Owners[0];
        address ownerToRemove = safeA1Owners[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        palmeraModule.removeOwner(
            zeroAddress, ownerToRemove, threshold, safeAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        palmeraModule.removeOwner(
            prevOwner, zeroAddress, threshold, safeAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        palmeraModule.removeOwner(
            sentinel, ownerToRemove, threshold, safeAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        palmeraModule.removeOwner(
            prevOwner, sentinel, threshold, safeAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> ROOT, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> Not Related,
    function testRevertInvalidThresholdRemoveOwner() public {
        (uint256 rootId, uint256 safeA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeA1);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        // (When threshold < 1)
        safeHelper.updateSafeInterface(safeA1Addr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = safeA1Owners[0];
        address removeOwner = safeA1Owners[1];
        uint256 zeroThreshold = 0;

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        palmeraModule.removeOwner(
            prevOwner, removeOwner, zeroThreshold, rootAddr, orgHash
        );

        // When threshold > max current threshold
        uint256 wrongThreshold = safeHelper.safeWallet().getOwners().length + 2;

        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        palmeraModule.removeOwner(
            prevOwner, removeOwner, wrongThreshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> NOT ROLE, Type -> SAFE, Hierarchy -> NOT_REGISTERED, Name -> fakeCaller
    // Target Info: Name -> fakeCaller, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredRemoveOwner_SAFE_Caller() public {
        address fakeCaller = safeHelper.newPalmeraSafe(4, 2);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        address prevOwner = owners[0];
        address ownerToRemove = owners[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(fakeCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, fakeCaller
            )
        );
        palmeraModule.removeOwner(
            prevOwner, ownerToRemove, threshold - 1, fakeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NOT ROLE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> invalidSafeCaller
    // Target Info: Name -> invalidSafeCaller, Type -> EOA, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredRemoveOwner_EOA_Caller() public {
        safeHelper.newPalmeraSafe(4, 2);
        address invalidSafeCaller = address(0x123);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        address prevOwner = owners[0];
        address ownerToRemove = owners[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(invalidSafeCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidSafe.selector, invalidSafeCaller
            )
        );
        palmeraModule.removeOwner(
            prevOwner, ownerToRemove, threshold - 1, invalidSafeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> ROOT, Name -> userLeadEOA
    // Target Info: Name -> safeA1Addr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by EOA,
    function testCan_RemoveOwner_SAFE_LEAD_as_EOA_is_TARGETS_LEAD() public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);

        address userLeadEOA = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLeadEOA, safeIdA1, true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(safeA1Addr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadEOA);
        palmeraModule.removeOwner(
            prevOwner, owner, threshold, safeA1Addr, orgHash
        );

        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> safe, Name -> safeA2Addr
    // Target Info: Name -> safeA1Addr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD() public {
        (uint256 rootId, uint256 safeIdA1, uint256 safeIdA2) =
        palmeraSafeBuilder.setupRootWithTwoSafes(
            orgName, safeA1Name, safeA2Name
        );

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address safeA2Addr = palmeraModule.getSafeAddress(safeIdA2);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeA2Addr, safeIdA1, true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(safeA1Addr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(safeA2Addr);
        safeHelper.removeOwnerTx(
            prevOwner, owner, threshold, safeA1Addr, orgHash
        );
        safeHelper.updateSafeInterface(safeA1Addr);
        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> safeA1Addr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testCan_RemoveOwner_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD_DifferentTree(
    ) public {
        (uint256 rootIdA, uint256 safeIdA1,, uint256 safeIdB1) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        vm.startPrank(rootAddrA);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeBAddr, safeIdA1, true
        );
        vm.stopPrank();

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        // SafeB RemoveOwner from safeA
        safeHelper.updateSafeInterface(safeBAddr);
        bool result = safeHelper.removeOwnerTx(
            safeA1Owners[0], safeA1Owners[1], threshold, safeAAddr, orgHash
        );
        assertEq(result, true);
        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), false);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> safe, Name -> safeAAddr
    // Target Info: Name -> safeA1Addr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE()
        public
    {
        (, uint256 safeIdA1, uint256 childIdA,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);
        address childAAddr = palmeraModule.getSafeAddress(childIdA);

        safeHelper.updateSafeInterface(childAAddr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(safeAAddr);
        safeHelper.removeOwnerTx(
            prevOwner, owner, threshold, childAAddr, orgHash
        );
        safeHelper.updateSafeInterface(childAAddr);
        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE()
        public
    {
        (uint256 rootIdA, uint256 safeIdA1,,,) = palmeraSafeBuilder
            .setupOrgThreeTiersTree(orgName, safeA1Name, subSafeA1Name);

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(rootAddrA);
        safeHelper.removeOwnerTx(
            prevOwner, owner, threshold, safeAAddr, orgHash
        );

        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testRevertRootSafeToAttemptTo_removeOwner_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 safeIdA1,, uint256 safeIdB1,,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeAndOneChildEach(
            orgName,
            safeA1Name,
            root2Name,
            safeBName,
            subSafeA1Name,
            "subSafeB1"
        );

        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = safeA1Owners[1];
        address removeOwner = safeA1Owners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        vm.startPrank(safeBAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);
        palmeraModule.removeOwner(
            prevOwner, removeOwner, threshold, safeAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrB
    // Target Info: Name -> rootAddrA, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testRevertRootSafeToAttemptTo_removeOwner_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA,, uint256 rootIdB,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address rootAddrB = palmeraModule.getSafeAddress(rootIdB);

        // Get safeA signers info
        safeHelper.updateSafeInterface(rootAddrA);
        address[] memory rootAOwners = safeHelper.safeWallet().getOwners();
        address prevOwner = rootAOwners[1];
        address removeOwner = rootAOwners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(rootAOwners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);
        palmeraModule.removeOwner(
            prevOwner, removeOwner, threshold, rootAddrA, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD_MODIFY_OWNERS_ONLY, Type -> SAFE, Hierarchy -> safe, Name -> safeBAddr
    // Target Info: Name -> safeAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootIdA, uint256 safeIdA1,, uint256 safeIdB1) =
        palmeraSafeBuilder.setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddrA = palmeraModule.getSafeAddress(rootIdA);
        address safeBAddr = palmeraModule.getSafeAddress(safeIdB1);
        address safeAAddr = palmeraModule.getSafeAddress(safeIdA1);

        vm.startPrank(rootAddrA);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            safeBAddr,
            safeIdA1,
            true
        );
        vm.stopPrank();
        assertEq(palmeraModule.isSafeLead(safeIdA1, safeBAddr), true);

        // Get safeA signers info
        safeHelper.updateSafeInterface(safeAAddr);
        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = safeA1Owners[1];
        address removeOwner = safeA1Owners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(safeA1Owners[1]), true);

        // SafeB AddOwnerWithThreshold from safeA
        safeHelper.updateSafeInterface(safeBAddr);
        bool result = safeHelper.removeOwnerTx(
            prevOwner, removeOwner, threshold, safeAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(safeAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, safeA1Owners.length - 1
        );
        assertEq(safeHelper.safeWallet().isOwner(removeOwner), false);
    }

    // Caller Info: Role-> SAFE_LEAD_MODIFY_OWNERS_ONLY, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> userLeadModifyOwnersOnly
    // Target Info: Name -> safeA1Addr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by caller,
    function testCan_RemoveOwner_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 safeIdA1) =
            palmeraSafeBuilder.setupRootOrgAndOneSafe(orgName, safeA1Name);

        address rootAddr = palmeraModule.getSafeAddress(rootId);
        address safeA1Addr = palmeraModule.getSafeAddress(safeIdA1);
        address userLeadModifyOwnersOnly = address(0x123);

        address[] memory safeA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = safeA1Owners[1];
        address removeOwner = safeA1Owners[2];

        vm.startPrank(rootAddr);
        palmeraModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            safeIdA1,
            true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(safeA1Addr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadModifyOwnersOnly);
        palmeraModule.removeOwner(
            prevOwner, removeOwner, threshold - 1, safeA1Addr, orgHash
        );

        assertEq(safeHelper.safeWallet().getThreshold(), threshold - 1);
        assertEq(safeHelper.safeWallet().isOwner(removeOwner), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootBAddr
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testRevertRootSafesToAttemptToRemoveFromExternalOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = palmeraSafeBuilder
            .setupTwoRootOrgWithOneSafeEach(
            orgName, safeA1Name, root2Name, safeBName
        );

        address rootAddr = palmeraModule.getSafeAddress(rootIdA);
        address rootBAddr = palmeraModule.getSafeAddress(rootIdB);

        address prevOwnerToRemoveOnOrgA = safeHelper.safeWallet().getOwners()[0];
        address ownerToRemove = safeHelper.safeWallet().getOwners()[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);

        vm.startPrank(rootBAddr);
        palmeraModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by caller,
    function testRevertOwnerNotFoundRemoveOwner() public {
        bool result = safeHelper.registerOrgTx(orgName);
        palmeraSafes[orgName] = address(safeHelper.safeWallet());
        vm.label(palmeraSafes[orgName], orgName);

        assertEq(result, true);

        address rootAddr = palmeraSafes[orgName];

        uint256 rootId = palmeraModule.getSafeIdBySafe(orgHash, rootAddr);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        palmeraModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address wrongOwnerToRemove = address(0xabdcf);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(ownersList.length, 3);

        vm.expectRevert(Errors.OwnerNotFound.selector);

        vm.startPrank(safeLead);

        palmeraModule.removeOwner(
            prevOwner, wrongOwnerToRemove, threshold, rootAddr, orgHash
        );
    }
}
