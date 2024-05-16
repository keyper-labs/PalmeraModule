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
    // Target Info: Name -> squadIdA1, Type -> SAFE, Hierarchy related to caller -> SAFE leading by caller
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            squadIdA1,
            true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(squadA1Addr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, squadA1Addr, orgHash
        );

        assertEq(safeHelper.safeWallet().getThreshold(), threshold + 1);
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> squad, Name -> squadBAddr
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootIdA, uint256 squadIdA1,, uint256 squadIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            squadBAddr,
            squadIdA1,
            true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(squadIdA1, squadBAddr), true);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        safeHelper.updateSafeInterface(squadBAddr);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, squadAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(squadAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, squadA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> squadAAddr
    // Target Info: Name -> childAAddr, Type -> SAFE,Hierarchy related to caller -> SAME_TREE,CHILDREN
    function testCan_AddOwnerWithThreshold_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 squadIdA1, uint256 childIdA,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);
        address childAAddr = keyperModule.getSquadSafeAddress(childIdA);

        // Get squadA signers info
        safeHelper.updateSafeInterface(childAAddr);
        address[] memory childA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(childA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        safeHelper.updateSafeInterface(squadAAddr);
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
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAME_TREE,CHILDREN
    function testCan_AddOwnerWithThreshold_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA, uint256 squadIdA1,,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        safeHelper.updateSafeInterface(rootAddrA);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, squadAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(squadAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, squadA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> SUPER, Name -> squadBAddr
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testRevertRootSafeToAttemptTo_AddOwnerWithThreshold_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 squadIdA1,, uint256 squadIdB1,,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        vm.startPrank(squadBAddr);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, squadAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrB
    // Target Info: Name -> rootAddrB, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testRevertRootSafeToAttemptTo_AddOwnerWithThreshold_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);

        // Get squadA signers info
        safeHelper.updateSafeInterface(rootAddrA);
        address[] memory rootAOwners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(rootAOwners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, rootAddrA, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> squad, Name -> squadA
    // Target Info: Name -> squadB, Type -> SAFE, Hierarchy related to caller -> DIFFERENT_TREE,
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD()
        public
    {
        (uint256 rootIdA, uint256 squadIdA1,, uint256 squadIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, squadBAddr, squadIdA1, true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(squadIdA1, squadBAddr), true);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        safeHelper.updateSafeInterface(squadBAddr);
        bool result = safeHelper.addOwnerWithThresholdTx(
            newOwner, threshold, squadAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(squadAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, squadA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> squad, Name -> rightCaller
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by rightCaller,
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_as_EOA_is_TARGETS_LEAD()
        public
    {
        (uint256 rootIdA, uint256 squadIdA1,,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address rightCaller = address(0x123);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, rightCaller, squadIdA1, true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(squadIdA1, rightCaller), true);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        vm.startPrank(rightCaller);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, squadAAddr, orgHash
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(squadAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, squadA1Owners.length + 1
        );
        assertEq(safeHelper.safeWallet().isOwner(newOwner), true);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by safeLead,
    function testRevertOwnerAlreadyExistsAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        assertEq(keyperModule.isSafeLead(rootId, safeLead), true);

        safeHelper.updateSafeInterface(rootAddr);
        address[] memory owners = safeHelper.safeWallet().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddr
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertZeroAddressAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);

        safeHelper.updateSafeInterface(rootAddr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.addOwnerWithThreshold(
            zeroAddress, threshold + 1, rootAddr, orgHash
        );

        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.addOwnerWithThreshold(
            sentinel, threshold + 1, rootAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertInvalidThresholdAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        // (When threshold < 1)
        address newOwner = address(0xf1f1f1);
        uint256 zeroThreshold = 0;

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        keyperModule.addOwnerWithThreshold(
            newOwner, zeroThreshold, rootAddr, orgHash
        );

        // When threshold > max current threshold
        uint256 wrongThreshold = safeHelper.safeWallet().getOwners().length + 2;

        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> NONE, Type -> SAFE, Hierarchy -> NOT_REGISTERED, Name -> safeNotRegistered
    // Target Info: Name -> safeNotRegistered, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredAddOwnerWithThreshold_SAFE_Caller()
        public
    {
        address safeNotRegistered = safeHelper.newKeyperSafe(4, 2);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        address newOwner = safeHelper.newKeyperSafe(4, 2);

        vm.startPrank(safeNotRegistered);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeNotRegistered.selector, safeNotRegistered
            )
        );
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, safeNotRegistered, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NONE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> InvalidSafeCaller
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredAddOwnerWithThreshold_EOA_Caller()
        public
    {
        safeHelper.newKeyperSafe(4, 2);
        address InvalidSafeCaller = address(0x123);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        address newOwner = safeHelper.newKeyperSafe(4, 2);

        vm.startPrank(InvalidSafeCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidSafe.selector, InvalidSafeCaller
            )
        );
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, InvalidSafeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NONE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> newOwnerOnOrgA
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> Not Related,
    function testRevertRootSafesAttemptToAddToExternalSafeOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootIdA);
        address rootBAddr = keyperModule.getSquadSafeAddress(rootIdB);

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);

        vm.startPrank(rootBAddr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, rootAddr, orgHash
        );
        vm.stopPrank();
    }

    // ! ********************* removeOwner Test ***********************************

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> fakeCaller
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAME_TREE,
    function testRevertZeroAddressProvidedRemoveOwner() public {
        (uint256 rootIdA, uint256 squadIdA1,,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address fakeCaller = keyperModule.getSquadSafeAddress(rootIdA);

        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = squadA1Owners[0];
        address ownerToRemove = squadA1Owners[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(fakeCaller);
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.removeOwner(
            zeroAddress, ownerToRemove, threshold, squadAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.removeOwner(
            prevOwner, zeroAddress, threshold, squadAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.removeOwner(
            sentinel, ownerToRemove, threshold, squadAAddr, orgHash
        );

        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        keyperModule.removeOwner(
            prevOwner, sentinel, threshold, squadAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> ROOT, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> Not Related,
    function testRevertInvalidThresholdRemoveOwner() public {
        (uint256 rootId, uint256 squadA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadA1);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        // (When threshold < 1)
        safeHelper.updateSafeInterface(squadA1Addr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = squadA1Owners[0];
        address removeOwner = squadA1Owners[1];
        uint256 zeroThreshold = 0;

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        keyperModule.removeOwner(
            prevOwner, removeOwner, zeroThreshold, rootAddr, orgHash
        );

        // When threshold > max current threshold
        uint256 wrongThreshold = safeHelper.safeWallet().getOwners().length + 2;

        vm.expectRevert(Errors.TxExecutionModuleFailed.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        keyperModule.removeOwner(
            prevOwner, removeOwner, wrongThreshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> NOT ROLE, Type -> SAFE, Hierarchy -> NOT_REGISTERED, Name -> fakeCaller
    // Target Info: Name -> fakeCaller, Type -> SAFE, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredRemoveOwner_SAFE_Caller() public {
        address fakeCaller = safeHelper.newKeyperSafe(4, 2);
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
        keyperModule.removeOwner(
            prevOwner, ownerToRemove, threshold - 1, fakeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> NOT ROLE, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> invalidSafeCaller
    // Target Info: Name -> invalidSafeCaller, Type -> EOA, Hierarchy related to caller -> ITSELF,
    function testRevertSafeNotRegisteredRemoveOwner_EOA_Caller() public {
        safeHelper.newKeyperSafe(4, 2);
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
        keyperModule.removeOwner(
            prevOwner, ownerToRemove, threshold - 1, invalidSafeCaller, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> ROOT, Name -> userLeadEOA
    // Target Info: Name -> squadA1Addr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by EOA,
    function testCan_RemoveOwner_SAFE_LEAD_as_EOA_is_TARGETS_LEAD() public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);

        address userLeadEOA = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLeadEOA, squadIdA1, true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(squadA1Addr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadEOA);
        keyperModule.removeOwner(
            prevOwner, owner, threshold, squadA1Addr, orgHash
        );

        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> squad, Name -> squadA2Addr
    // Target Info: Name -> squadA1Addr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD() public {
        (uint256 rootId, uint256 squadIdA1, uint256 squadIdA2) =
        keyperSafeBuilder.setupRootWithTwoSquads(
            orgName, squadA1Name, squadA2Name
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address squadA2Addr = keyperModule.getSquadSafeAddress(squadIdA2);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, squadA2Addr, squadIdA1, true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(squadA1Addr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(squadA2Addr);
        safeHelper.removeOwnerTx(
            prevOwner, owner, threshold, squadA1Addr, orgHash
        );
        safeHelper.updateSafeInterface(squadA1Addr);
        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> squadA1Addr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testCan_RemoveOwner_SAFE_LEAD_as_SAFE_is_TARGETS_LEAD_DifferentTree(
    ) public {
        (uint256 rootIdA, uint256 squadIdA1,, uint256 squadIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, squadBAddr, squadIdA1, true
        );
        vm.stopPrank();

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        // SquadB RemoveOwner from squadA
        safeHelper.updateSafeInterface(squadBAddr);
        bool result = safeHelper.removeOwnerTx(
            squadA1Owners[0], squadA1Owners[1], threshold, squadAAddr, orgHash
        );
        assertEq(result, true);
        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), false);
    }

    // Caller Info: Role-> SUPER_SAFE, Type -> SAFE, Hierarchy -> squad, Name -> squadAAddr
    // Target Info: Name -> squadA1Addr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE()
        public
    {
        (, uint256 squadIdA1, uint256 childIdA,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);
        address childAAddr = keyperModule.getSquadSafeAddress(childIdA);

        safeHelper.updateSafeInterface(childAAddr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(squadAAddr);
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
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE()
        public
    {
        (uint256 rootIdA, uint256 squadIdA1,,,) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, squadA1Name, subSquadA1Name);

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        safeHelper.updateSafeInterface(rootAddrA);
        safeHelper.removeOwnerTx(
            prevOwner, owner, threshold, squadAAddr, orgHash
        );

        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory postRemoveOwnersList =
            safeHelper.safeWallet().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(safeHelper.safeWallet().isOwner(owner), false);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrA
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testRevertRootSafeToAttemptTo_removeOwner_SUPER_SAFE_as_SAFE_is_TARGETS_SUPER_SAFE(
    ) public {
        (, uint256 squadIdA1,, uint256 squadIdB1,,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadAndOneChildEach(
            orgName,
            squadA1Name,
            root2Name,
            squadBName,
            subSquadA1Name,
            "subSquadB1"
        );

        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = squadA1Owners[1];
        address removeOwner = squadA1Owners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        vm.startPrank(squadBAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);
        keyperModule.removeOwner(
            prevOwner, removeOwner, threshold, squadAAddr, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootAddrB
    // Target Info: Name -> rootAddrA, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testRevertRootSafeToAttemptTo_removeOwner_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SAFE(
    ) public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address rootAddrB = keyperModule.getSquadSafeAddress(rootIdB);

        // Get squadA signers info
        safeHelper.updateSafeInterface(rootAddrA);
        address[] memory rootAOwners = safeHelper.safeWallet().getOwners();
        address prevOwner = rootAOwners[1];
        address removeOwner = rootAOwners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(rootAOwners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        vm.startPrank(rootAddrB);
        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);
        keyperModule.removeOwner(
            prevOwner, removeOwner, threshold, rootAddrA, orgHash
        );
        vm.stopPrank();
    }

    // Caller Info: Role-> SAFE_LEAD_MODIFY_OWNERS_ONLY, Type -> SAFE, Hierarchy -> squad, Name -> squadBAddr
    // Target Info: Name -> squadAAddr, Type -> SAFE, Hierarchy related to caller -> SAME TREE,
    function testCan_RemoveOwner_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootIdA, uint256 squadIdA1,, uint256 squadIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddrA = keyperModule.getSquadSafeAddress(rootIdA);
        address squadBAddr = keyperModule.getSquadSafeAddress(squadIdB1);
        address squadAAddr = keyperModule.getSquadSafeAddress(squadIdA1);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            squadBAddr,
            squadIdA1,
            true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(squadIdA1, squadBAddr), true);

        // Get squadA signers info
        safeHelper.updateSafeInterface(squadAAddr);
        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = squadA1Owners[1];
        address removeOwner = squadA1Owners[2];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(safeHelper.safeWallet().isOwner(squadA1Owners[1]), true);

        // SquadB AddOwnerWithThreshold from squadA
        safeHelper.updateSafeInterface(squadBAddr);
        bool result = safeHelper.removeOwnerTx(
            prevOwner, removeOwner, threshold, squadAAddr, orgHash
        );
        assertEq(result, true);

        safeHelper.updateSafeInterface(squadAAddr);
        assertEq(safeHelper.safeWallet().getThreshold(), threshold);
        assertEq(
            safeHelper.safeWallet().getOwners().length, squadA1Owners.length - 1
        );
        assertEq(safeHelper.safeWallet().isOwner(removeOwner), false);
    }

    // Caller Info: Role-> SAFE_LEAD_MODIFY_OWNERS_ONLY, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> userLeadModifyOwnersOnly
    // Target Info: Name -> squadA1Addr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by caller,
    function testCan_RemoveOwner_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 squadIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneSquad(orgName, squadA1Name);

        address rootAddr = keyperModule.getSquadSafeAddress(rootId);
        address squadA1Addr = keyperModule.getSquadSafeAddress(squadIdA1);
        address userLeadModifyOwnersOnly = address(0x123);

        address[] memory squadA1Owners = safeHelper.safeWallet().getOwners();
        address prevOwner = squadA1Owners[1];
        address removeOwner = squadA1Owners[2];

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            squadIdA1,
            true
        );
        vm.stopPrank();

        safeHelper.updateSafeInterface(squadA1Addr);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.startPrank(userLeadModifyOwnersOnly);
        keyperModule.removeOwner(
            prevOwner, removeOwner, threshold - 1, squadA1Addr, orgHash
        );

        assertEq(safeHelper.safeWallet().getThreshold(), threshold - 1);
        assertEq(safeHelper.safeWallet().isOwner(removeOwner), false);
    }

    // Caller Info: Role-> ROOT_SAFE, Type -> SAFE, Hierarchy -> ROOT, Name -> rootBAddr
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> DIFFERENT TREE,
    function testRevertRootSafesToAttemptToRemoveFromExternalOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneSquadEach(
            orgName, squadA1Name, root2Name, squadBName
        );

        address rootAddr = keyperModule.getSquadSafeAddress(rootIdA);
        address rootBAddr = keyperModule.getSquadSafeAddress(rootIdB);

        address prevOwnerToRemoveOnOrgA = safeHelper.safeWallet().getOwners()[0];
        address ownerToRemove = safeHelper.safeWallet().getOwners()[1];
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);

        vm.startPrank(rootBAddr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, rootAddr, orgHash
        );
    }

    // Caller Info: Role-> SAFE_LEAD, Type -> EOA, Hierarchy -> NOT_REGISTERED, Name -> safeLead
    // Target Info: Name -> rootAddr, Type -> SAFE, Hierarchy related to caller -> SAFE Leading by caller,
    function testRevertOwnerNotFoundRemoveOwner() public {
        bool result = safeHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(safeHelper.safeWallet());
        vm.label(keyperSafes[orgName], orgName);

        assertEq(result, true);

        address rootAddr = keyperSafes[orgName];

        uint256 rootId = keyperModule.getSquadIdBySafe(orgHash, rootAddr);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        address[] memory ownersList = safeHelper.safeWallet().getOwners();

        address prevOwner = ownersList[0];
        address wrongOwnerToRemove = address(0xabdcf);
        uint256 threshold = safeHelper.safeWallet().getThreshold();

        assertEq(ownersList.length, 3);

        vm.expectRevert(Errors.OwnerNotFound.selector);

        vm.startPrank(safeLead);

        keyperModule.removeOwner(
            prevOwner, wrongOwnerToRemove, threshold, rootAddr, orgHash
        );
    }
}
