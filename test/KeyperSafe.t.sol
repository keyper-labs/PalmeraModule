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
    string org2Name = "Second Org";
    string groupA1Name = "GroupA1";
    string groupA2Name = "GroupA2";
    string groupBName = "GroupB";
    string subGroupA1Name = "subGroupA1";
    string subSubgroupA1Name = "SubSubGroupA";
    string rootBName = "rootB";

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
        (uint256 orgRootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeGroupA1Id);
        (,,, address safeSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeSubGroupA1Id);

        // Send ETH to group&subgroup
        vm.deal(safeGroupA1Addr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);

        /// Enable allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableAllowlist();
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1Addr,
            safeSubGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        // Execute on behalf function
        vm.startPrank(safeGroupA1Addr);
        vm.expectRevert(Errors.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgId,
            safeSubGroupA1Addr,
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
        (uint256 orgRootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeGroupA1Id);
        (,,, address safeSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeSubGroupA1Id);
        // Send ETH to group&subgroup
        vm.deal(safeGroupA1Addr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);
        address[] memory receiverList = new address[](1);
        receiverList[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableDenylist();
        keyperModule.addToList(receiverList);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1Addr,
            safeSubGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        // Execute on behalf function
        vm.startPrank(safeGroupA1Addr);
        vm.expectRevert(Errors.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgId,
            safeSubGroupA1Addr,
            receiverList[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // ! ********************* addOwnerWithThreshold Test ***********************

    // addOwnerWithThreshold
    // Caller: userLeadModifyOwnersOnly
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD_MODIFY_OWNERS_ONLY of safeGroupA1
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testAddOwnerWithThreshold() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(groupIdA1);

        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            groupIdA1,
            true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        address[] memory prevOwnersList = gnosisHelper.gnosisSafe().getOwners();
        bytes32 orgId = keyperModule.getOrgBySafe(safeGroupA1Addr);

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, safeGroupA1Addr, orgId
        );

        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold + 1);

        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();
        assertEq(ownersList.length, prevOwnersList.length + 1);

        address ownerTest;
        for (uint256 i = 0; i < ownersList.length; i++) {
            if (ownersList[i] == newOwner) {
                ownerTest = ownersList[i];
            }
        }
        assertEq(ownerTest, newOwner);
    }

    // Revert OwnerAlreadyExists() addOwnerWithThreshold (Attempting to add an existing owner)
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertOwnerAlreadyExists() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        address safeLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        assertEq(keyperModule.isSafeLead(rootId, safeLead), true);

        gnosisHelper.updateSafeInterface(orgAddr);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, orgAddr, orgId
        );
    }

    // Revert InvalidThreshold() addOwnerWithThreshold (When threshold < 1)
    // Scenario 1
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioOne()
        public
    {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        address safeLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold = 0;
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFaild.selector); // safe Contract Internal Error GS202 "Threshold needs to be greater than 0"
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, orgAddr, orgId
        );
    }

    // Revert InvalidThreshold() addOwnerWithThreshold (When threshold > (IGnosisSafe(targetSafe).getOwners().length.add(1)))
    // Scenario 2
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioTwo()
        public
    {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        address safeLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, safeLead, rootId, true);
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(orgAddr);
        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold =
            gnosisHelper.gnosisSafe().getOwners().length + 2;
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.startPrank(safeLead);
        vm.expectRevert(Errors.TxExecutionModuleFaild.selector); // safe Contract Internal Error GS201 "Threshold cannot exceed owner count"
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, orgAddr, orgId
        );
    }

    // Revert NotAuthorizedAsNotSafeLead() addOwnerWithThreshold (Attempting to add an owner from an external org)
    // Caller: org2Addr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE for org2
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertRootSafesAttemptToAddToExternalSafeOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, rootBName, groupBName
        );

        (,,, address rootAddr,,) = keyperModule.getGroupInfo(rootIdA);
        (,,, address rootBAddr,,) = keyperModule.getGroupInfo(rootIdB);

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(rootAddr);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);

        vm.startPrank(rootBAddr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, rootAddr, orgId
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

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(groupIdA1);

        address userLeadEOA = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLeadEOA, groupIdA1, true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(safeGroupA1Addr);

        vm.startPrank(userLeadEOA);
        keyperModule.removeOwner(
            prevOwner, owner, threshold, safeGroupA1Addr, orgId
        );

        address[] memory postRemoveOwnersList =
            gnosisHelper.gnosisSafe().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(gnosisHelper.gnosisSafe().isOwner(owner), false);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold);
    }

    // Revert NotAuthorizedAsNotSafeLead() removeOwner (Attempting to remove an owner from an external org)
    // Caller: org2Addr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE of org2
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertRootSafesToAttemptToRemoveFromExternalOrg() public {
        (uint256 rootIdA,, uint256 rootIdB,) = keyperSafeBuilder
            .setupTwoRootOrgWithOneGroupEach(
            orgName, groupA1Name, rootBName, groupBName
        );

        (,,, address rootAddr,,) = keyperModule.getGroupInfo(rootIdA);
        (,,, address rootBAddr,,) = keyperModule.getGroupInfo(rootIdB);

        address prevOwnerToRemoveOnOrgA =
            gnosisHelper.gnosisSafe().getOwners()[0];
        address ownerToRemove = gnosisHelper.gnosisSafe().getOwners()[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(rootAddr);

        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);

        vm.startPrank(rootBAddr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, rootAddr, orgId
        );
    }

    // Revert OwnerNotFound() removeOwner (attempting to remove an owner that is not exist as an owner of the safe)
    // Caller: safeLead
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testRevertOwnerNotFoundRemoveOwner() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        uint256 rootId = keyperModule.getGroupIdBySafe(orgId, orgAddr);
        address safeLead = address(0x123);

        vm.startPrank(orgAddr);
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
            prevOwner, wrongOwnerToRemove, threshold, orgAddr, orgId
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
    // Caller: orgAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromOrg() public {
        (uint256 orgRootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(safeGroupA1Id);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(orgRootId, safeGroupA1Id), false);

        // Check safeSubGroupA1 is now a child of org
        assertEq(keyperModule.isTreeMember(orgRootId, safeSubGroupA1Id), true);
        // Check org is parent of safeSubGroupA1
        assertEq(keyperModule.isSuperSafe(orgRootId, safeSubGroupA1Id), true);
    }

    /// removeGroup when org == superSafe
    // Caller: orgAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRemoveGroupFromSafeOrgEqSuperSafe() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        // Create a sub safe
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);
        bool result = gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1Name);
        assertEq(result, true);
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        uint256 safeSubGroupA1Id =
            keyperModule.getGroupIdBySafe(orgId, safeSubGroupA1);

        gnosisHelper.updateSafeInterface(orgAddr);
        result = gnosisHelper.createRemoveGroupTx(groupIdA1);
        assertEq(result, true);

        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), false);

        uint256[] memory child;
        (,,,, child,) = keyperModule.getGroupInfo(rootId);
        // Check removed group parent has subSafeGroup A as child an not safeGroupA1
        assertEq(child.length, 1);
        assertEq(child[0] == groupIdA1, false);
        assertEq(child[0] == safeSubGroupA1Id, true);
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), false);
    }

    // ? Org call removeGroup for a group of another org
    // Caller: orgAddr, orgAddr2
    // Caller Type: rootSafe
    // Caller Role: N/A
    // TargerSafe: safeGroupA1, safeGroupA2
    // TargetSafe Type: safe as a child
    // Deploy 4 keyperSafes : following structure
    //           RootOrg1                    RootOrg2
    //              |                            |
    //         safeGroupA1                 safeGroupA2
    // Must Revert if RootOrg1 attempt to remove GroupA2
    function testRevertRemoveGroupFromAnotherOrg() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(org2Name);
        keyperSafes[org2Name] = address(gnosisHelper.gnosisSafe());

        address orgAddr = keyperSafes[orgName];
        address org2Addr = keyperSafes[org2Name];

        bytes32 rootId = keyperModule.getOrgBySafe(orgAddr);
        bytes32 root2Id = keyperModule.getOrgBySafe(org2Addr);

        uint256 orgId = keyperModule.getGroupIdBySafe(rootId, orgAddr);
        uint256 org2Id = keyperModule.getGroupIdBySafe(root2Id, org2Addr);

        address safeGroupA1Addr = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[groupA1Name] = address(safeGroupA1Addr);
        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        result = gnosisHelper.createAddGroupTx(orgId, groupA1Name);
        assertEq(result, true);
        uint256 safeGroupA1 =
            keyperModule.getGroupIdBySafe(rootId, safeGroupA1Addr);

        address safeGroupA2Addr = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[groupA2Name] = address(safeGroupA2Addr);
        gnosisHelper.updateSafeInterface(safeGroupA2Addr);
        result = gnosisHelper.createAddGroupTx(org2Id, groupA2Name);
        assertEq(result, true);
        uint256 safeGroupA2 =
            keyperModule.getGroupIdBySafe(root2Id, safeGroupA2Addr);

        vm.startPrank(orgAddr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(safeGroupA2);
        vm.stopPrank();

        vm.startPrank(org2Addr);
        vm.expectRevert(Errors.NotAuthorizedRemoveGroupFromOtherTree.selector);
        keyperModule.removeGroup(safeGroupA1);
    }

    // ? Check disableSafeLeadRoles method success
    // groupA1 removed and it should not have any role
    function testRemoveGroupAndCheckDisables() public {
        (uint256 orgAddr1, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr1Addr,,) = keyperModule.getGroupInfo(orgAddr1);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);

        (,,,,, uint256 superSafe) = keyperModule.getGroupInfo(safeGroupA1);
        bytes32 orgId = keyperModule.getOrgByGroup(superSafe);
        (,, address superSafeAddr,,) = keyperModule.groups(orgId, superSafe);

        gnosisHelper.updateSafeInterface(orgAddr1Addr);
        bool result = gnosisHelper.createRemoveGroupTx(safeGroupA1);
        assertEq(result, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
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
    // Caller: orgAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: userLead
    // TargetSafe Type: EOA
    function testsetSafeLead() public {
        (uint256 orgAddr1, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr1Addr,,) = keyperModule.getGroupInfo(orgAddr1);

        address userLead = address(0x123);

        vm.startPrank(orgAddr1Addr);
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
            orgName, groupA1Name, rootBName, groupBName
        );

        address rootAddrA = keyperModule.getGroupSafeAddress(rootIdA);
        address groupBAddr = keyperModule.getGroupSafeAddress(groupIdB1);
        address groupAAddr = keyperModule.getGroupSafeAddress(groupIdA1);
        bytes32 orgHash = keyperModule.getOrgBySafe(rootAddrA);

        vm.startPrank(rootAddrA);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, groupBAddr, groupIdA1, true
        );
        vm.stopPrank();

        assertEq(keyperModule.isSafeLead(groupIdA1, groupBAddr), true);

        gnosisHelper.updateSafeInterface(groupAAddr);
        address[] memory groupA1Owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(groupAAddr), groupA1Owners[1]),
            true
        );

        vm.startPrank(groupBAddr);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, groupAAddr, orgHash
        );
        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(groupAAddr), newOwner), true
        );

        // TODO use removeOwner tx as caller is a safe
        keyperModule.removeOwner(
            groupA1Owners[0], groupA1Owners[1], threshold, groupAAddr, orgHash
        );
        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(groupAAddr), groupA1Owners[1]),
            false
        );
    }

    // Attempt to set a forbidden role to an EOA
    // Caller: orgAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SUPER_SAFE
    // TargerSafe: user
    // TargetSafe Type: EOA
    function testRevertSetRoleForbidden() public {
        (uint256 orgAddr1, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr1Addr,,) = keyperModule.getGroupInfo(orgAddr1);

        address user = address(0xABCDE);

        vm.startPrank(orgAddr1Addr);
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
        (, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);

        address user = address(0xABCDE);

        vm.startPrank(safeGroupA1Addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisRootSafe.selector, safeGroupA1Addr
            )
        );
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, user, safeGroupA1, true);
    }

    // ! ****************** Reentrancy Attack Test to execOnBehalf ***************

    function testReentrancyAttack() public {
        Attacker attackerContract = new Attacker(address(keyperModule));
        AttackerHelper attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(
            keyperModule, attackerContract, gnosisHelper, 30
        );

        (address orgAddr, address attacker, address victim) =
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
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        bool result = attackerContract.performAttack(
            orgId,
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
