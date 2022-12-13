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

    // ! ********************** execTransactionOnBehalf Test ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree(
    ) public {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgId,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // execTransactionOnBehalf when msg.sender is a lead (not a RootSafe)
    // Caller: safeGroupB
    // Caller Type: safe
    // Caller Role: SAFE_LEAD of safeSubSubGroupA1
    // TargerSafe: safeSubSubGroupA1
    // TargetSafe Type: group (not a child)
    //            rootSafe
    //           |        |
    //  safeGroupA1       safeGroupB
    //      |
    // safeSubGroupA1
    //      |
    // safeSubSubGroupA1
    function testLeadExecOnBehalfFromGroup() public {
        (uint256 orgRootId,, uint256 safeGroupBId,, uint256 safeSubSubGroupA1Id)
        = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, groupA1Name, groupBName, subGroupA1Name, subSubgroupA1Name
        );
        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupBAddr,,) = keyperModule.getGroupInfo(safeGroupBId);
        (,,, address safeSubSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeSubSubGroupA1Id);

        vm.deal(safeSubSubGroupA1Addr, 100 gwei);
        vm.deal(safeGroupBAddr, 100 gwei);

        vm.startPrank(orgAddr);
        bytes32 orgId = keyperModule.getOrgByGroup(orgRootId);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupBAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            false
        );
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeGroupBAddr, safeSubSubGroupA1Id, true
        );
        vm.stopPrank();

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupBAddr, uint8(DataTypes.Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            keyperModule.isSafeLead(safeSubSubGroupA1Id, safeGroupBAddr), true
        );
        assertEq(
            keyperModule.isSuperSafe(safeGroupBId, safeSubSubGroupA1Id), false
        );
        // Set keyperhelper gnosis safe to org
        vm.startPrank(safeGroupBAddr);
        keyperHelper.setGnosisSafe(safeGroupBAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupBAddr,
            safeSubSubGroupA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        bool result = keyperModule.execTransactionOnBehalf(
            orgId,
            safeSubSubGroupA1Addr,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 12 gwei);
    }

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargerSafe: safeSubGroupA1, same hierachical tree with 2 levels diff
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1          |
    //              |                 |
    //           safeSubGroupA1 <-----
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree_2_levels(
    ) public {
        (uint256 orgRootId,, uint256 safeSubGroupA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeSubGroupA1Id);

        vm.deal(orgAddr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to org
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeSubGroupA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgId,
            safeSubGroupA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 25 gwei);
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when arg "to" is address(0)
    // Scenario 1
    // Caller: orgAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgId,
            safeGroupA1Addr,
            fakeReceiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "targetSafe" is address(0)
    // Scenario 2
    // Caller: orgAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, address(0)
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgId,
            address(0),
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert ZeroAddressProvided() execTransactionOnBehalf when param "org" is address(0)
    // Scenario 3
    // Caller: orgAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertOrgNotRegisteredExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.OrgNotRegistered.selector, address(0))
        );
        keyperModule.execTransactionOnBehalf(
            bytes32(0),
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert InvalidGnosisSafe() execTransactionOnBehalf : when param "targetSafe" is not a safe
    // Caller: orgAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SAFE_LEAD
    // TargerSafe: fakeTargetSafe
    // TargetSafe Type: EOA
    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakeTargetSafe
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgId,
            fakeTargetSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert NotAuthorizedAsNotSafeLead() execTransactionOnBehalf : safe lead of another org/group
    // Caller: fakeCaller
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of the org
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);
        keyperHelper.setGnosisSafe(orgAddr);
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);

        // Random wallet instead of a safe (EOA)

        vm.startPrank(fakeCaller);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "fakeGroup");
        vm.stopPrank();
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, fakeCaller, orgRootId, true
        );
        vm.stopPrank();

        //Vefiry that fakeCaller is a safe lead
        assertEq(keyperModule.isSafeLead(orgRootId, fakeCaller), true);

        vm.startPrank(fakeCaller);
        bytes32 orgId = keyperModule.getOrgBySafe(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgId,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // execTransactionOnBehalf when SafeLead of an Org as EOA
    // Caller: callerEOA
    // Caller Type: EOA
    // Caller Role: SAFE_LEAD of org
    // TargerSafe: orgAddr
    // TargetSafe Type: rootSafe
    function testEoaCallExecTransactionOnBehalfScenarioTwo() public {
        (uint256 orgRootId,,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        keyperHelper.setGnosisSafe(orgAddr);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Set safe_lead role to fake caller
        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, callerEOA, orgRootId, true
        );
        vm.stopPrank();
        bytes memory emptyData;
        bytes memory signatures;
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgId,
            orgAddr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // Revert "UNAUTHORIZED" execTransactionOnBehalf (Caller is an EOA but he's not the lead (no role provided to EOA))
    // Caller: fakeCaller
    // Caller Type: EOA
    // Caller Role: N/A (NO ROLE PROVIDED)
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioThree()
        public
    {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);
        keyperHelper.setGnosisSafe(orgAddr);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        vm.startPrank(fakeCaller);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.execTransactionOnBehalf(
            orgId,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert "GS026" execTransactionOnBehalf (invalid signatures provided)
    // Caller: orgAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 orgRootId, uint256 safeGroupA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(orgRootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(safeGroupA1);
        keyperHelper.setGnosisSafe(orgAddr);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            orgAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.expectRevert("GS026");
        // Execute invalid OnBehalf function
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgId,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    // execTransactionOnBehalf
    // Caller: safeGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE of safeSubGroupA1
    // TargerSafe: safeSubGroupA1
    // TargetSafe Type: safe
    //            rootSafe
    //               |
    //           safeGroupA1 as superSafe ---
    //              |                        |
    //           safeSubGroupA1 <------------
    function testSuperSafeExecOnBehalf() public {
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
        /// Verify if the safeGroupA1Addr have the role to execute, executionTransactionOnBehalf
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );

        // Execute on behalf function
        vm.startPrank(safeGroupA1Addr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgId,
            safeSubGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // Revert NotAuthorizedExecOnBehalf() execTransactionOnBehalf (safeSubGroupA1 is attempting to execute on its superSafe)
    // Caller: safeSubGroupA1
    // Caller Type: safe
    // Caller Role: SUPER_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as lead
    //            rootSafe
    //           |
    //  safeGroupA1 <----
    //      |            |
    // safeSubGroupA1 ---
    //      |
    // safeSubSubGroupA1
    function testRevertSuperSafeExecOnBehalf() public {
        (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 subGroupIdA1,
            uint256 subSubGroupIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(groupIdA1);
        (,,, address safeSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(subGroupIdA1);
        (,,, address safeSubSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(subSubGroupIdA1);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubSubGroupA1Addr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );

        // Send ETH to org&subgroup
        vm.deal(orgAddr, 100 gwei);
        vm.deal(safeGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to safeSubGroupA1
        keyperHelper.setGnosisSafe(safeSubGroupA1Addr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeSubGroupA1Addr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);

        vm.startPrank(safeSubGroupA1Addr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgId,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
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

        /// Enalbe allowlist
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
        (uint256 rootId, uint256 groupIdA1,) =
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
        (uint256 rootId,,) =
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
        (uint256 rootId,,) =
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
        (uint256 rootId,,) =
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
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(org2Name);
        keyperSafes[org2Name] = address(gnosisHelper.gnosisSafe());

        address orgAddr = keyperSafes[orgName];
        address org2Addr = keyperSafes[org2Name];

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        vm.expectRevert(Errors.NotAuthorizedAddOwnerWithThreshold.selector);

        vm.startPrank(org2Addr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, orgAddr, orgId
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
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address orgAddr,,) = keyperModule.getGroupInfo(rootId);
        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(groupIdA1);

        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, userLead, groupIdA1, true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(safeGroupA1Addr);

        vm.startPrank(userLead);
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
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(org2Name);
        keyperSafes[org2Name] = address(gnosisHelper.gnosisSafe());

        address orgAddr = keyperSafes[orgName];
        address org2Addr = keyperSafes[org2Name];

        address prevOwnerToRemoveOnOrgA =
            gnosisHelper.gnosisSafe().getOwners()[0];
        address ownerToRemove = gnosisHelper.gnosisSafe().getOwners()[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);

        vm.expectRevert(Errors.NotAuthorizedRemoveOwner.selector);

        vm.startPrank(org2Addr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, orgAddr, orgId
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

    // registerOrg
    function testRegisterOrgFromSafe() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        assertEq(result, true);
        bytes32 orgId =
            keyperModule.getOrgBySafe(address(gnosisHelper.gnosisSafe()));
        assertEq(orgId, keccak256(abi.encodePacked(orgName)));
        uint256 rootId = keyperModule.getGroupIdBySafe(
            orgId, address(gnosisHelper.gnosisSafe())
        );
        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getGroupInfo(rootId);
        assertEq(uint8(tier), uint8(DataTypes.Tier.ROOT));
        assertEq(name, orgName);
        assertEq(lead, address(0));
        assertEq(safe, gnosisSafeAddr);
        assertEq(superSafe, 0);
        assertEq(child.length, 0);
        assertEq(keyperModule.isOrgRegistered(orgId), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safe, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );
    }

    // Revert ("UNAUTHORIZED") registerOrg (address that has no roles)
    function testRevertAuthForRegisterOrgTx() public {
        address caller = address(0x1);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        keyperRolesContract.setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD), caller, Constants.ADD_OWNER, true
        );
    }

    // ! ******************** addGroup Test ****************************************

    // superSafe == org
    function testCreateGroupFromSafe() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);
        address orgAddr = keyperSafes[orgName];
        bytes32 orgId = keyperModule.getOrgBySafe(orgAddr);
        uint256 rootId = keyperModule.getGroupIdBySafe(orgId, orgAddr);

        address safeGroupA1 = gnosisHelper.newKeyperSafe(4, 2);
        keyperSafes[groupA1Name] = address(safeGroupA1);
        vm.label(keyperSafes[groupA1Name], groupA1Name);

        gnosisHelper.updateSafeInterface(safeGroupA1);
        result = gnosisHelper.createAddGroupTx(rootId, groupA1Name);
        assertEq(result, true);
        uint256 groupA1Id = keyperModule.getGroupIdBySafe(orgId, safeGroupA1);

        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getGroupInfo(groupA1Id);

        (,, address orgLead,,,) = keyperModule.getGroupInfo(rootId);

        assertEq(uint8(tier), uint8(DataTypes.Tier.GROUP));
        assertEq(name, groupA1Name);
        assertEq(lead, orgLead);
        assertEq(safe, safeGroupA1);
        assertEq(child.length, 0);
        assertEq(superSafe, rootId);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    // superSafe != org
    function testCreateGroupFromSafeScenario2() public {
        (uint256 orgRootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        (,,, address safeGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeGroupA1Id);
        (,,, address safeSubGroupA1Addr,,) =
            keyperModule.getGroupInfo(safeSubGroupA1Id);

        (
            DataTypes.Tier tier,
            string memory name,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getGroupInfo(safeGroupA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.GROUP));
        assertEq(name, groupA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeGroupA1Addr);
        assertEq(child.length, 1);
        assertEq(child[0], safeSubGroupA1Id);
        assertEq(superSafe, orgRootId);

        /// Reuse the local-variable for avoid stack too deep error
        (tier, name, lead, safe, child, superSafe) =
            keyperModule.getGroupInfo(safeSubGroupA1Id);

        assertEq(uint8(tier), uint8(DataTypes.Tier.GROUP));
        assertEq(name, subGroupA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeSubGroupA1Addr);
        assertEq(child.length, 0);
        assertEq(superSafe, safeGroupA1Id);
    }

    // Revert ChildAlreadyExist() addGroup (Attempting to add a group when its child already exist)
    // Caller: safeSubGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertGroupAlreadyRegisteredAddGroup() public {
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        (,,, address safeGroupA1Addr,,) = keyperModule.getGroupInfo(groupIdA1);

        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);

        gnosisHelper.updateSafeInterface(safeSubGroupA1);

        bool result = gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1Name);
        assertEq(result, true);

        vm.startPrank(safeSubGroupA1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SafeAlreadyRegistered.selector, safeSubGroupA1
            )
        );
        keyperModule.addGroup(groupIdA1, subGroupA1Name);

        vm.deal(safeSubGroupA1, 1 ether);
        gnosisHelper.updateSafeInterface(safeSubGroupA1);

        vm.expectRevert();
        result = gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1Name);
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
        (uint256 rootId, uint256 groupIdA1,) =
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
        (uint256 orgAddr1, uint256 safeGroupA1,) =
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
        (uint256 orgAddr1, uint256 safeGroupA1,) =
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

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            DataTypes.Role.SAFE_LEAD, safeGroupA2Addr, safeGroupA1, true
        );
        vm.stopPrank();

        assertEq(keyperModule.isSafeLead(safeGroupA1, safeGroupA2Addr), true);

        gnosisHelper.updateSafeInterface(safeGroupA1Addr);
        address[] memory groupA1Owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(
            keyperModule.isSafeOwner(
                IGnosisSafe(safeGroupA1Addr), groupA1Owners[1]
            ),
            true
        );

        vm.startPrank(safeGroupA2Addr);

        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, safeGroupA1Addr, rootId
        );
        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(safeGroupA1Addr), newOwner),
            true
        );

        keyperModule.removeOwner(
            groupA1Owners[0],
            groupA1Owners[1],
            threshold,
            safeGroupA1Addr,
            rootId
        );
        assertEq(
            keyperModule.isSafeOwner(
                IGnosisSafe(safeGroupA1Addr), groupA1Owners[1]
            ),
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
        (uint256 orgAddr1, uint256 safeGroupA1,) =
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
        (, uint256 safeGroupA1,) =
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
