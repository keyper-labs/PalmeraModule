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

contract ExecTransactionOnBehalf is Test {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;
    KeyperSafeBuilder keyperSafeBuilder;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    address receiver = address(0xABC);
    string public orgName = "Main Org";
    string public org2Name = "Second Org";
    string public groupA1Name = "GroupA1";
    string public groupA2Name = "GroupA2";
    string public groupBName = "GroupB";
    string public subGroupA1Name = "subGroupA1";
    string public subSubgroupA1Name = "SubSubGroupA";

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;

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

    // ! ********************** execTransactionOnBehalf Test ********************

    // Caller Info: ROOT_SAFE(role), SAFE(type), rootSafe(hierachie)
    // TargetSafe Type: Child from same hierachical tree
    function testCan_ExecTransactionOnBehalf_ROOT_SAFE_and_Target_Root_SameTree(
    ) public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
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
        (uint256 rootId,, uint256 safeGroupBId,, uint256 safeSubSubGroupA1Id) =
        keyperSafeBuilder.setUpBaseOrgTree(
            orgName, groupA1Name, groupBName, subGroupA1Name, subSubgroupA1Name
        );
        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupBAddr = keyperModule.getGroupSafeAddress(safeGroupBId);
        address safeSubSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubSubGroupA1Id);

        vm.deal(safeSubSubGroupA1Addr, 100 gwei);
        vm.deal(safeGroupBAddr, 100 gwei);

        vm.startPrank(rootAddr);
        bytes32 orgHash = keyperModule.getOrgByGroup(rootId);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.ROOT_SAFE)
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
            orgHash,
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
        (uint256 rootId,, uint256 safeSubGroupA1Id) = keyperSafeBuilder
            .setupOrgThreeTiersTree(orgName, groupA1Name, subGroupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubGroupA1Id);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeSubGroupA1Addr, 100 gwei);

        // Set keyperhelper gnosis safe to org
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeSubGroupA1Addr,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        gnosisHelper.updateSafeInterface(rootAddr);
        bool result = gnosisHelper.execTransactionOnBehalfTx(
            orgHash,
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
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe as a Child
    //            rootSafe -----------
    //               |                |
    //           safeGroupA1 <--------
    function testRevertInvalidAddressProvidedExecTransactionOnBehalfScenarioOne(
    ) public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(Errors.InvalidAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
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
    // Caller: rootAddr (org)
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
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, address(0)
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
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
    // Caller: rootAddr (org)
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
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
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
    // Caller: rootAddr (org)
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE, SAFE_LEAD
    // TargerSafe: fakeTargetSafe
    // TargetSafe Type: EOA
    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(rootAddr);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, fakeTargetSafe
            )
        );
        keyperModule.execTransactionOnBehalf(
            orgHash,
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
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);
        address fakeCaller = gnosisHelper.newKeyperSafe(4, 2);

        // Random wallet instead of a safe (EOA)

        vm.startPrank(fakeCaller);
        bool result = gnosisHelper.createAddGroupTx(safeGroupA1, "fakeGroup");
        vm.stopPrank();
        assertEq(result, true);

        // Set keyperhelper gnosis safe to org
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, fakeCaller, rootId, true);
        vm.stopPrank();

        //Vefiry that fakeCaller is a safe lead
        assertEq(keyperModule.isSafeLead(rootId, fakeCaller), true);

        vm.startPrank(fakeCaller);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(fakeCaller);
        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgHash,
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
    // TargerSafe: rootAddr
    // TargetSafe Type: rootSafe
    function testEoaCallExecTransactionOnBehalfScenarioTwo() public {
        (uint256 rootId,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        keyperHelper.setGnosisSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);

        // Set safe_lead role to fake caller
        vm.startPrank(rootAddr);
        keyperModule.setRole(DataTypes.Role.SAFE_LEAD, callerEOA, rootId, true);
        vm.stopPrank();
        bytes memory emptyData;
        bytes memory signatures;
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            rootAddr,
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
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);

        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        vm.startPrank(fakeCaller);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Revert "GS026" execTransactionOnBehalf (invalid signatures provided)
    // Caller: rootAddr
    // Caller Type: rootSafe
    // Caller Role: ROOT_SAFE
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertInvalidSignatureExecOnBehalf() public {
        (uint256 rootId, uint256 safeGroupA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(safeGroupA1);
        keyperHelper.setGnosisSafe(rootAddr);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(rootAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            rootAddr,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.expectRevert("GS026");
        // Execute invalid OnBehalf function
        vm.startPrank(rootAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
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
        (uint256 rootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeGroupA1Id);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubGroupA1Id);

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
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
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
            orgHash,
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
        (uint256 rootId, uint256 groupIdA1, uint256 subGroupIdA1,) =
        keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(subGroupIdA1);

        // Send ETH to org&subgroup
        vm.deal(rootAddr, 100 gwei);
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
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);

        vm.expectRevert(Errors.NotAuthorizedExecOnBehalf.selector);

        vm.startPrank(safeSubGroupA1Addr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgHash,
            safeGroupA1Addr,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    function testOrgFourTiersTreeSuperSafeRoles() public {
        (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 subGroupIdA1,
            uint256 subSubGroupIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );

        address rootAddr = keyperModule.getGroupSafeAddress(rootId);
        address safeGroupA1Addr = keyperModule.getGroupSafeAddress(groupIdA1);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(subGroupIdA1);
        address safeSubSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(subSubGroupIdA1);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
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
    }

    // Missing scenarios:

    // 1: Org with a root safe with 3 child levels: A, B, C
    //    Group A starts a executeOnBehalf tx for his children B
    //    -> The calldata for the function is another executeOnBehalfTx for children C
    //       -> Verify that this wrapped executeOnBehalf tx does not work
}
