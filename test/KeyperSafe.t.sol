// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import "./helpers/KeyperModuleHelper.t.sol";
import "./helpers/ReentrancyAttackHelper.t.sol";
import "./helpers/KeyperSafeBuilder.t.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {Attacker} from "../src/ReentrancyAttack.sol";
import {console} from "forge-std/console.sol";

contract TestKeyperSafe is Test, SigningUtils {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;
    KeyperSafeBuilder keyperSafeBuilder;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    address receiver = address(0xABC);

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;
    string orgName = "Main Org";
    string root2Name = "Second Root";
    string groupA1Name = "GroupA1";
    string groupA2Name = "GroupA2";
    string groupBName = "GroupB";
    string subGroupA1Name = "subGroupA1";
    string subSubgroupA1Name = "SubSubGroupA";

    function setUp() public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();

        // setting keyperRoles Address
        gnosisHelper.setKeyperRoles(keyperRolesDeployed);

        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());

        keyperModule = new KeyperModule(
            masterCopy,
            safeFactory,
            address(keyperRolesDeployed)
        );
        keyperModuleAddr = address(keyperModule);
        // Init keyperModuleHelper
        keyperHelper = new KeyperModuleHelper();
        keyperHelper.initHelper(keyperModule, 30);
        // Update gnosisHelper
        gnosisHelper.setKeyperModule(keyperModuleAddr);
        // Enable keyper module
        gnosisHelper.enableModuleTx(gnosisSafeAddr);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        keyperRolesContract = KeyperRoles(factory.deploy(salt, bytecode));

        keyperSafeBuilder = new KeyperSafeBuilder();
        // keyperSafeBuilder.setGnosisHelper(GnosisSafeHelper(gnosisHelper));
        keyperSafeBuilder.setUpParams(
            KeyperModule(keyperModule), GnosisSafeHelper(gnosisHelper)
        );
    }

    // ! ********************** authority Test **********************************

    // Checks if authority == keyperRoles
    function testAuthorityAddress() public {
        assertEq(
            address(keyperModule.authority()), address(keyperRolesDeployed)
        );
    }

    // ! ********************** createSafeFactory Test **************************

    // Checks if a safe is created successfully from Module
    function testCreateSafeFromModule() public {
        address newSafe = keyperHelper.createSafeProxy(4, 2);
        assertFalse(newSafe == address(0));
        // Verify newSafe has keyper modulle enabled
        GnosisSafe safe = GnosisSafe(payable(newSafe));
        bool isKeyperModuleEnabled =
            safe.isModuleEnabled(address(keyperHelper.keyper()));
        assertEq(isKeyperModuleEnabled, true);
    }

    // ! ********************** Allow/Deny list Test ********************

    // Revert AddresNotAllowed() execTransactionOnBehalf (safeGroupA1 is not on AllowList)
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
    function testRevertSuperSafeExecOnBehalfIsNotAllowList() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(groupA1Addr, 100 gwei);
        vm.deal(subGroupA1Addr, 100 gwei);

        /// Enable allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableAllowlist();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(groupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA1Addr,
            subGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Execute on behalf function
        vm.startPrank(groupA1Addr);
        vm.expectRevert(Errors.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            subGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert AddressDenied() execTransactionOnBehalf (safeGroupA1 is on DeniedList)
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
    // Result: Revert
    function testRevertSuperSafeExecOnBehalfIsDenyList() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);
        address subGroupA1Addr = keyperModule.getGroupSafeAddress(subGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(groupA1Addr, 100 gwei);
        vm.deal(subGroupA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(rootAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(groupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA1Addr,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        // Execute on behalf function
        vm.startPrank(groupA1Addr);
        vm.expectRevert(Errors.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
            subGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // ! ********************* addOwnerWithThreshold Test ***********************

    // Caller Type: EOA
    // Caller Role: SAFE_LEAD_MODIFY_OWNERS_ONLY of safeGroupA1
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_EOA_is_TARGETS_LEAD(
    ) public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            groupIdA1,
            true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(groupA1Addr);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        bytes32 orgHash = keyperModule.getOrgHashBySafe(groupA1Addr);

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, groupA1Addr, orgHash
        );

        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold + 1);
        assertEq(gnosisHelper.gnosisSafe().isOwner(newOwner), true);
    }

    function testCan_AddOwnerWithThreshold_SAFE_LEAD_MODIFY_OWNERS_ONLY_as_SAFE_is_TARGETS_LEAD(
    ) public {
        (uint256 rootIdA, uint256 groupIdA1,, uint256 groupIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address groupBAddr = keyperModule.getGroupSafeAddress(groupIdB1);
        address groupAAddr = keyperModule.getGroupSafeAddress(groupIdA1);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            groupBAddr,
            groupIdA1,
            true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(groupIdA1, groupBAddr), true);

        // Get groupA signers info
        gnosisHelper.updateSafeInterface(groupAAddr);
        address[] memory groupA1Owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(gnosisHelper.gnosisSafe().isOwner(groupA1Owners[1]), true);

        // GroupB AddOwnerWithThreshold from groupA
        gnosisHelper.updateSafeInterface(groupBAddr);
        bool result = gnosisHelper.addOwnerWithThresholdTx(
            newOwner, threshold, groupAAddr, orgHash
        );
        assertEq(result, true);

        gnosisHelper.updateSafeInterface(groupAAddr);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold);
        assertEq(
            gnosisHelper.gnosisSafe().getOwners().length,
            groupA1Owners.length + 1
        );
        assertEq(gnosisHelper.gnosisSafe().isOwner(newOwner), true);
    }

    // Revert OwnerAlreadyExists() addOwnerWithThreshold (Attempting to add an existing owner)
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testRevertOwnerAlreadyExistsAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        assertEq(keyperModule.isSafeLead(rootId, safeLead), true);

        gnosisHelper.updateSafeInterface(rootAddr);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, rootAddr, orgHash
        );
    }

    // Revert InvalidThreshold() addOwnerWithThreshold
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: rootAddr
    function testRevertInvalidThresholdAddOwnerWithThreshold() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        // (When threshold < 1)
        address newOwner = address(0xf1f1f1);
        uint256 zeroThreshold = 0;
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFaild.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        keyperModule.addOwnerWithThreshold(
            newOwner, zeroThreshold, rootAddr, orgHash
        );

        // When threshold > max current threshold
        uint256 wrongThreshold =
            gnosisHelper.gnosisSafe().getOwners().length + 2;

        vm.expectRevert(Errors.TxExecutionModuleFaild.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, rootAddr, orgHash
        );
    }

    // Revert NotAuthorizedAsNotSafeLead() addOwnerWithThreshold (Attempting to add an owner from an external org)
    // Caller: org2Addr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE for org2
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testRevertRootSafesAttemptToAddToExternalSafeOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootIdA);
        address rootBAddr = keyperModule.getGroupSafeAddress(rootIdB);

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);

        vm.startPrank(rootBAddr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, rootAddr, orgHash
        );
    }

    //     // ! ********************* removeOwner Test ***********************************

    // removeOwner
    // Caller: userLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of safeGroupA1
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveOwner() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);

        address userLeadEOA = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLeadEOA, groupIdA1, true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(groupA1Addr);
        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgHash = keyperModule.getOrgHashBySafe(groupA1Addr);

        vm.startPrank(userLeadEOA);
        keyperModule.removeOwner(
            prevOwner, owner, threshold, groupA1Addr, orgHash
        );

        address[] memory postRemoveOwnersList =
            gnosisHelper.gnosisSafe().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(gnosisHelper.gnosisSafe().isOwner(owner), false);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold);
    }

    // Empower a safe to modify another safe from another org
    // Caller: safeGroupA2
    // Caller Type: safe
    // Caller Role: SAFE_LEAD
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    // Deploy 4 keyperSafes : following structure
    //           RootOrg1                    RootOrg2
    //              |                            |
    //           safeGroupA1                safeGroupA2
    // safeGroupA2 will be a safeLead of safeGroupA1
    function testModifyFromAnotherOrg() public {
        (uint256 rootIdA, uint256 groupIdA1,, uint256 groupIdB1) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address groupBAddr = keyperModule.getGroupSafeAddress(groupIdB1);
        address groupAAddr = keyperModule.getGroupSafeAddress(groupIdA1);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddrA);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, groupBAddr, groupIdA1, true
        );
        vm.stopPrank();
        assertEq(keyperModule.isSafeLead(groupIdA1, groupBAddr), true);

        // Get groupA signers info
        gnosisHelper.updateSafeInterface(groupAAddr);
        address[] memory groupA1Owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(gnosisHelper.gnosisSafe().isOwner(groupA1Owners[1]), true);

        // GroupB AddOwnerWithThreshold from groupA
        gnosisHelper.updateSafeInterface(groupBAddr);
        bool result = gnosisHelper.addOwnerWithThresholdTx(
            newOwner, threshold, groupAAddr, orgHash
        );
        assertEq(result, true);
        gnosisHelper.updateSafeInterface(groupAAddr);
        assertEq(gnosisHelper.gnosisSafe().isOwner(newOwner), true);

        // GroupB RemoveOwner from groupA
        gnosisHelper.updateSafeInterface(groupBAddr);
        result = gnosisHelper.createRemoveOwnerTx(
            groupA1Owners[0], groupA1Owners[1], threshold, groupAAddr, orgHash
        );
        assertEq(result, true);
        assertEq(gnosisHelper.gnosisSafe().isOwner(groupA1Owners[1]), false);
    }

    // Revert NotAuthorizedAsNotSafeLead() removeOwner (Attempting to remove an owner from an external org)
    // Caller: org2Addr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE of org2
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testRevertRootSafesToAttemptToRemoveFromExternalOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootIdA);
        address rootBAddr = keyperModule.getGroupSafeAddress(rootIdB);

        address prevOwnerToRemoveOnOrgA =
            gnosisHelper.gnosisSafe().getOwners()[0];
        address ownerToRemove = gnosisHelper.gnosisSafe().getOwners()[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);

        vm.startPrank(rootBAddr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, rootAddr, orgHash
        );
    }

    // Revert OwnerNotFound() removeOwner (attempting to remove an owner that is not exist as an owner of the safe)
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testRevertOwnerNotFoundRemoveOwner() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        assertEq(result, true);

        address rootAddr = keyperSafes[orgName];
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        uint256 rootId = keyperModule.getGroupIdBySafe(orgHash, rootAddr);
        address safeLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address wrongOwnerToRemove = address(0xabdcf);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(ownersList.length, 3);

        vm.expectRevert(Errors.OwnerNotFound.selector);

        vm.startPrank(safeLead);

        keyperModule.removeOwner(
            prevOwner, wrongOwnerToRemove, threshold, rootAddr, orgHash
        );
    }

    // ! ******************** registerOrg Test *************************************

    // Revert ("UNAUTHORIZED") registerOrg (address that has no roles)
    function testRevertAuthForRegisterOrgTx() public {
        address caller = address(0x1);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        keyperRolesContract.setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD), caller, Constants.ADD_OWNER, true
        );
    }

    // ! ******************** removeGroup Test *************************************

    // removeGroup
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromOrg() public {
        (uint256 rootId, uint256 groupA1Id, uint256 subGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(rootId, groupA1Id), false);

        // Check safeSubGroupA1 is now a child of org
        assertEq(keyperModule.isTreeMember(rootId, subGroupA1Id), true);
        // Check org is parent of safeSubGroupA1
        assertEq(keyperModule.isSuperSafe(rootId, subGroupA1Id), true);
    }

    /// removeGroup when org == superSafe
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromSafeOrgEqSuperSafe() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        // Create a sub safe
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);
        bool result = gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1Name);
        assertEq(result, true);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        uint256 subGroupA1Id =
            keyperModule.getGroupIdBySafe(orgHash, safeSubGroupA1);

        gnosisHelper.updateSafeInterface(rootAddr);
        result = gnosisHelper.createRemoveGroupTx(groupIdA1);
        assertEq(result, true);

        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), false);

        uint256[] memory child;
        (,,,, child,) = keyperModule.getGroupInfo(rootId);
        // Check removed group parent has subSafeGroup A as child an not safeGroupA1
        assertEq(child.length, 1);
        assertEq(child[0] == groupIdA1, false);
        assertEq(child[0] == subGroupA1Id, true);
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), false);
    }

    // ? Org call removeGroup for a group of another org
    // Caller: rootAddr, rootAddr2
    // Caller Type: rootSafe
    // Caller Role: N/A
    // TargerSafe: safeGroupA1, safeGroupA2
    // TargetSafe Type: safe as a child
    // Deploy 4 keyperSafes : following structure
    //           Root                    RootB
    //             |                       |
    //         groupA                 groupB
    // Must Revert if RootOrg1 attempt to remove GroupA2
    function testRevertRemoveGroupFromAnotherOrg() public {
        (uint256 rootIdA, uint256 groupAId, uint256 rootIdB, uint256 groupBId) =
        keyperSafeBuilder.setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, root2Name, groupBName
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootIdA);
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(groupBId);
        vm.stopPrank();

        address rootBAddr = keyperModule.getGroupSafeAddress(rootIdB);
        vm.startPrank(rootBAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(groupAId);
    }

    // ? Check disableSafeLeadRoles method success
    // groupA1 removed and it should not have any role
    function testRemoveGroupAndCheckDisables() public {
        (uint256 rootId, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);

        (,,,,, uint256 superSafe) = keyperModule.getGroupInfo(groupA1Id);
        bytes32 orgHash = keyperModule.getOrgByGroup(superSafe);
        (,, address superSafeAddr,,) = keyperModule.groups(orgHash, superSafe);

        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.createRemoveGroupTx(groupA1Id);
        assertEq(result, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafeAddr,
                uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
    }

    // ! ******************* setRole Test *****************************************

    // setLead as a role at setRole Test
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: userLead
    // TargetSafe Type: EOA
    function testsetSafeLead() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address userLead = address(0x123);

        vm.startPrank(rootAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLead, safeGroupA1, true
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userLead, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
    }

    // Attempt to set a forbidden role to an EOA
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: user
    // TargetSafe Type: EOA
    function testRevertSetRoleForbidden() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        address user = address(0xABCDE);

        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 4)
        );
        keyperModule.setRole(DataTypes.Role.ROOT_SAFE, user, safeGroupA1, true);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(DataTypes.Role.SUPER_SAFE, user, safeGroupA1, true);
    }

    // Attempt to set a forbidden role to an EOA
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: user
    // TargetSafe Type: EOA
    function testRevertSetRolesToOrgNotRegistered() public {
        (, uint256 groupA1Id) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address groupA1Addr = keyperModule.getGroupSafeAddress(groupA1Id);

        address user = address(0xABCDE);

        vm.startPrank(groupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, groupA1Addr
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, groupA1Id, true);
    }

    // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(keyperModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            keyperModule, attackerContract, gnosisHelper, 30
        );

        (address rootAddr, address attacker, address victim) =
            attackerHelper.setAttackerTree(orgName);

        gnosisHelper.updateSafeInterface(victim);
        attackerContract.setOwners(gnosisHelper.gnosisSafe().getOwners());

        gnosisHelper.updateSafeInterface(attacker);
        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper
            .encodeSignaturesForAttackKeyperTx(
            attacker, victim, attacker, 5 gwei, emptyData, Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        bool result = attackerContract.performAttack(
            orgHash,
            victim,
            attacker,
            5 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );

        assertEq(result, true);

        // This is the expected behavior since the nonReentrant modifier is blocking the attacker from draining the victim's funds nor transfer any amount
        assertEq(attackerContract.getBalanceFromSafe(victim), 100 gwei);
        assertEq(attackerContract.getBalanceFromAttacker(), 0);
    }
}
