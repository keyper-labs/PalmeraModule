// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import "./ReentrancyAttackHelper.t.sol";
import {KeyperModule, IGnosisSafe, DenyHelper} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {Attacker} from "../src/ReentrancyAttack.sol";
import {console} from "forge-std/console.sol";

contract TestKeyperSafe is Test, SigningUtils, Constants {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;
    Attacker attackerContract;
    AttackerHelper attackerHelper;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    address attackerAddr;

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

        attackerContract = new Attacker(keyperModuleAddr);
        attackerAddr = address(attackerContract);

        attackerHelper = new AttackerHelper();
        attackerHelper.initHelper(keyperModule, attackerContract, 30);
    }

    function testCreateSafeFromModule() public {
        address newSafe = keyperHelper.createSafeProxy(4, 2);
        assertFalse(newSafe == address(0));
        // Verify newSafe has keyper modulle enabled
        GnosisSafe safe = GnosisSafe(payable(newSafe));
        bool isKeyperModuleEnabled =
            safe.isModuleEnabled(address(keyperHelper.keyper()));
        assertEq(isKeyperModuleEnabled, true);
    }

    function testRegisterOrgFromSafe() public {
        // Create registerOrg calldata
        bool result = gnosisHelper.registerOrgTx(orgName);
        assertEq(result, true);
        (
            string memory name,
            address lead,
            address safe,
            address[] memory child,
            address superSafe
        ) = keyperModule.getOrg(gnosisSafeAddr);
        assertEq(name, orgName);
        assertEq(lead, address(0));
        assertEq(safe, gnosisSafeAddr);
        assertEq(superSafe, address(0));
        assertEq(child.length, 0);
        assertEq(keyperModule.isOrgRegistered(gnosisSafeAddr), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(safe, uint8(Role.ROOT_SAFE)),
            true
        );
    }

    // superSafe == org
    function testCreateGroupFromSafe() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        // Create new safe with setup called while creating contract
        address safeGroupA1 = gnosisHelper.newKeyperSafe(4, 2);
        // Create Group calldata
        keyperSafes[groupA1Name] = address(safeGroupA1);
        vm.label(keyperSafes[groupA1Name], groupA1Name);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupA1Name);
        assertEq(result, true);

        (
            string memory name,
            address lead,
            address safe,
            address[] memory child,
            address superSafe
        ) = keyperModule.getGroupInfo(orgAddr, safeGroupA1);

        (, address orgLead,,,) = keyperModule.getOrg(orgAddr);

        assertEq(name, groupA1Name);
        assertEq(lead, orgLead);
        assertEq(safe, safeGroupA1);
        assertEq(child.length, 0);
        assertEq(superSafe, orgAddr);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(Role.SUPER_SAFE)
            ),
            true
        );
    }

    // superSafe != org
    function testCreateGroupFromSafeScenario2() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        (
            string memory name,
            address lead,
            address safe,
            address[] memory child,
            address superSafe
        ) = keyperModule.getGroupInfo(orgAddr, safeGroupA1);

        assertEq(name, groupA1Name);
        assertEq(lead, address(0));
        assertEq(safe, safeGroupA1);
        assertEq(child.length, 1);
        assertEq(child[0], safeSubGroupA1);
        assertEq(superSafe, orgAddr);

        (
            string memory nameSubGroup,
            address leadSubGroup,
            address safeSubGroup,
            address[] memory childSubGroup,
            address superSubGroup
        ) = keyperModule.getGroupInfo(orgAddr, safeSubGroupA1);

        assertEq(nameSubGroup, subGroupA1Name);
        assertEq(leadSubGroup, address(0));
        assertEq(safeSubGroup, safeSubGroupA1);
        assertEq(childSubGroup.length, 1);
        assertEq(superSubGroup, safeGroupA1);
    }

    function testRevertChildrenAlreadyExistAddGroup() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);

        bool result =
            gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, subGroupA1Name);
        assertEq(result, true);

        vm.startPrank(safeSubGroupA1);
        vm.expectRevert(KeyperModule.ChildAlreadyExist.selector);
        keyperModule.addGroup(orgAddr, safeGroupA1, subGroupA1Name);

        vm.deal(safeSubGroupA1, 1 ether);
        gnosisHelper.updateSafeInterface(safeSubGroupA1);

        vm.expectRevert();
        result =
            gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, subGroupA1Name);
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           groupA1
    function setUpRootOrgAndOneGroup(
        string memory _orgName,
        string memory _groupName
    ) public returns (address, address) {
        // Set initial safe as a rootOrg
        bool result = gnosisHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        // Create Group calldata
        keyperSafes[_groupName] = address(groupSafe);

        address orgAddr = keyperSafes[_orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, _groupName);

        // Send ETH to org&subgroup
        vm.deal(orgAddr, 100 gwei);
        vm.deal(groupSafe, 100 gwei);

        return (orgAddr, groupSafe);
    }

    function setSafeLeadOfOrg() public returns (address, address) {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);
        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, orgAddr, true);
        vm.stopPrank();

        return (orgAddr, userLead);
    }

    // When msg.sender is RootSafe
    function testLeadExecOnBehalf() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // 1. When msg.sender is a lead (not a RootSafe)
    function testLeadExecOnBehalfFromGroup() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeSubSubGroupA1 = keyperSafes[subSubgroupA1Name];
        address safeGroupB = keyperSafes[groupBName];

        vm.deal(safeSubSubGroupA1, 100 gwei);
        vm.deal(safeGroupB, 100 gwei);
        address receiver = address(0xABC);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            Role.SAFE_LEAD, safeGroupB, safeSubSubGroupA1, true
        );
        vm.stopPrank();

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupB, uint8(Role.SAFE_LEAD)
            ),
            true
        );
        assertEq(
            keyperModule.isSafeLead(orgAddr, safeSubSubGroupA1, safeGroupB),
            true
        );
        assertEq(
            keyperModule.isSuperSafe(orgAddr, safeGroupB, safeSubSubGroupA1),
            false
        );
        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(safeGroupB);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupB,
            safeSubSubGroupA1,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.startPrank(safeGroupB);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeSubSubGroupA1,
            receiver,
            12 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 12 gwei);
    }

    // Rootsafe on subGroupA
    function testRootSafeExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        vm.deal(orgAddr, 100 gwei);
        vm.deal(safeSubGroupA1, 100 gwei);
        address receiver = address(0xABC);

        assertEq(
            keyperRolesContract.doesUserHaveRole(orgAddr, uint8(Role.ROOT_SAFE)),
            true
        );
        assertEq(
            keyperModule.isSafeLead(orgAddr, safeSubGroupA1, orgAddr), false
        );
        assertEq(
            keyperModule.isSuperSafe(orgAddr, orgAddr, safeSubGroupA1), true
        );

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr,
            safeSubGroupA1,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0)
        );
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeSubGroupA1,
            receiver,
            25 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 25 gwei);
    }

    // When to == address(0)
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioOne()
        public
    {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address receiver = address(0xABC);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            fakeReceiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // When targetSafe == address(0)
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            address(0),
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // When org == address(0)
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioThree()
        public
    {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            address(0),
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address receiver = address(0xABC);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(KeyperModule.InvalidGnosisSafe.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            fakeTargetSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // Conditions:
    // 2. Revert SafeLead as EOA
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioTwo()
        public
    {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures;

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, fakeCaller, orgAddr, true);
        vm.stopPrank();

        vm.startPrank(fakeCaller);
        vm.expectRevert(KeyperModule.NotAuthorizedAsNotSafeLead.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    // 3. SafeLead of an Org as EOA
    function testEoaCallExecTransactionOnBehalfScenarioTwo() public {
        (address orgAddr,) = setUpRootOrgAndOneGroup(orgName, groupA1Name);

        // Random wallet instead of a safe (EOA)
        address callerEOA = address(0xFED);
        address receiver = address(0xABC);

        // Set safe_lead role to fake caller
        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, callerEOA, orgAddr, true);
        vm.stopPrank();
        bytes memory emptyData;
        bytes memory signatures;
        vm.startPrank(callerEOA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
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

    // 4. Caller is an EOA but he's not the lead (no role provided)
    function testRevertNotAuthorizedExecTransactionOnBehalfScenarioThree()
        public
    {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        // Random wallet instead of a safe (EOA)
        address fakeCaller = address(0xFED);
        address receiver = address(0xABC);

        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        vm.startPrank(fakeCaller);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertInvalidSignatureExecOnBehalf() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);
        address receiver = address(0xABC);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            orgAddr, safeGroupA1, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );

        vm.expectRevert("GS026");
        // Execute invalid OnBehalf function
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      groupA1   GroupB
    //        |
    //  subGroupA1
    //      |
    //  SubSubGroupA1
    function setUpBaseOrgTree() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address safeGroupA1 = gnosisHelper.newKeyperSafe(3, 1);
        // Create AddGroup calldata
        keyperSafes[groupA1Name] = address(safeGroupA1);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupA1Name);

        // Create new safe with setup called while creating contract
        address safeGroupB = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[groupBName] = address(safeGroupB);

        orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupBName);

        // Create new safe with setup called while creating contract
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);
        orgAddr = keyperSafes[orgName];
        result =
            gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, subGroupA1Name);

        // Create new safe with setup called while creating contract
        address safeSubSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        keyperSafes[subSubgroupA1Name] = address(safeSubSubGroupA1);
        orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(
            orgAddr, safeSubGroupA1, subSubgroupA1Name
        );
    }

    function testSuperSafeExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        // Send ETH to group&subgroup
        vm.deal(safeGroupA1, 100 gwei);
        vm.deal(safeSubGroupA1, 100 gwei);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1,
            safeSubGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeGroupA1);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeSubGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    function testRevertSuperSafeExecOnBehalfIsNotAllowList() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        // Send ETH to group&subgroup
        vm.deal(safeGroupA1, 100 gwei);
        vm.deal(safeSubGroupA1, 100 gwei);
        address receiver = address(0xABC);

        /// Enalbe allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableAllowlist(orgAddr);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1,
            safeSubGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeGroupA1);
        vm.expectRevert(DenyHelper.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeSubGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertSuperSafeExecOnBehalfIsDenyList() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        // Send ETH to group&subgroup
        vm.deal(safeGroupA1, 100 gwei);
        vm.deal(safeSubGroupA1, 100 gwei);
        address[] memory receiver = new address[](1);
        receiver[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableDenylist(orgAddr);
        keyperModule.addToList(orgAddr, receiver);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to safeGroupA1
        keyperHelper.setGnosisSafe(safeGroupA1);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeGroupA1,
            safeSubGroupA1,
            receiver[0],
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(safeGroupA1);
        vm.expectRevert(DenyHelper.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeSubGroupA1,
            receiver[0],
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertSuperSafeExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];
        address safeSubSubGroupA = keyperSafes[subSubgroupA1Name];

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1, uint8(Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubGroupA1, uint8(Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeSubSubGroupA, uint8(Role.SUPER_SAFE)
            ),
            false
        );

        // Send ETH to org&subgroup
        vm.deal(orgAddr, 100 gwei);
        vm.deal(safeGroupA1, 100 gwei);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to safeSubGroupA1
        keyperHelper.setGnosisSafe(safeSubGroupA1);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            safeSubGroupA1,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
        );

        vm.expectRevert(KeyperModule.NotAuthorizedExecOnBehalf.selector);

        vm.startPrank(safeSubGroupA1);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            safeGroupA1,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, false);
    }

    function testAuthorityAddress() public {
        assertEq(
            address(keyperModule.authority()), address(keyperRolesDeployed)
        );
    }

    function testRevertAuthForRegisterOrgTx() public {
        address caller = address(0x1);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        keyperRolesContract.setRoleCapability(
            uint8(Role.SAFE_LEAD), caller, ADD_OWNER, true
        );
    }

    function testsetSafeLead() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, safeGroupA1, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userLead, uint8(Role.SAFE_LEAD)
            ),
            true
        );
    }

    function testAddOwnerWithThreshold() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            safeGroupA1,
            true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(safeGroupA1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        address[] memory prevOwnersList = gnosisHelper.gnosisSafe().getOwners();

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, safeGroupA1, orgAddr
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

    function testIsUserLeadWithThreshold() public {
        (address orgAddr, address safeLead) = setSafeLeadOfOrg();

        assertEq(keyperModule.isSafeLead(orgAddr, orgAddr, safeLead), true);

        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.startPrank(safeLead);
        vm.expectRevert(KeyperModule.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, orgAddr, orgAddr
        );
    }

    // When threshold < 1
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioOne()
        public
    {
        (address orgAddr, address safeLead) = setSafeLeadOfOrg();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold = 0;

        vm.startPrank(safeLead);
        vm.expectRevert(KeyperModule.InvalidThreshold.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, orgAddr, orgAddr
        );
    }

    // When threshold > (IGnosisSafe(targetSafe).getOwners().length.add(1))
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioTwo()
        public
    {
        (address orgAddr, address safeLead) = setSafeLeadOfOrg();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold =
            gnosisHelper.gnosisSafe().getOwners().length + 2;

        vm.startPrank(safeLead);
        vm.expectRevert(KeyperModule.InvalidThreshold.selector);
        keyperModule.addOwnerWithThreshold(
            newOwner, wrongThreshold, orgAddr, orgAddr
        );
    }

    function testRemoveOwner() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, safeGroupA1, true);
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(safeGroupA1);
        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.startPrank(userLead);
        keyperModule.removeOwner(
            prevOwner, owner, threshold, safeGroupA1, orgAddr
        );

        address[] memory postRemoveOwnersList =
            gnosisHelper.gnosisSafe().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(gnosisHelper.gnosisSafe().isOwner(owner), false);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold);
    }

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
        vm.expectRevert(KeyperModule.NotAuthorizedAsNotSafeLead.selector);

        vm.startPrank(org2Addr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, orgAddr, orgAddr
        );
    }

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

        vm.expectRevert(KeyperModule.NotAuthorizedAsNotSafeLead.selector);

        vm.startPrank(org2Addr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, orgAddr, orgAddr
        );
    }

    function testRevertOwnerNotFoundRemoveOwner() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        address safeLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, safeLead, orgAddr, true);
        vm.stopPrank();

        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address wrongOwnerToRemove = address(0xabdcf);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(ownersList.length, 3);

        vm.expectRevert(KeyperModule.OwnerNotFound.selector);

        vm.startPrank(safeLead);

        keyperModule.removeOwner(
            prevOwner, wrongOwnerToRemove, threshold, orgAddr, orgAddr
        );
    }

    // ! removeGroup

    function testRemoveGroupFromOrg() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address safeGroupA1 = keyperSafes[groupA1Name];
        address safeSubGroupA1 = keyperSafes[subGroupA1Name];

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, safeGroupA1);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(orgAddr, orgAddr, safeGroupA1), false);

        // Check safeSubGroupA1 is now a child of org
        assertEq(keyperModule.isChild(orgAddr, orgAddr, safeSubGroupA1), true);
        // Check org is parent of safeSubGroupA1
        assertEq(
            keyperModule.isSuperSafe(orgAddr, orgAddr, safeSubGroupA1), true
        );
    }

    /// removeGroup when org == superSafe
    function testRemoveGroupFromSafeOrgEqSuperSafe() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);
        // Create a sub safe
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupA1Name] = address(safeSubGroupA1);
        gnosisHelper.createAddGroupTx(orgAddr, safeGroupA1, subGroupA1Name);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, safeGroupA1);

        assertEq(result, true);

        result = keyperModule.isSuperSafe(orgAddr, orgAddr, safeGroupA1);
        assertEq(result, false);

        address[] memory child;
        (,,, child,) = keyperModule.getOrg(orgAddr);
        // Check removed group parent has subSafeGroup A as child an not safeGroupA1
        assertEq(child.length, 1);
        assertEq(child[0] == safeGroupA1, false);
        assertEq(child[0] == safeSubGroupA1, true);
        assertEq(
            keyperModule.isChild(orgAddr, safeGroupA1, safeSubGroupA1), false
        );
    }

    function testRevertSetRoleForbidden() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address user = address(0xABCDE);

        vm.startPrank(orgAddr);
        vm.expectRevert(
            abi.encodeWithSelector(KeyperModule.SetRoleForbidden.selector, 3)
        );
        keyperModule.setRole(Role.ROOT_SAFE, user, safeGroupA1, true);

        vm.expectRevert(
            abi.encodeWithSelector(KeyperModule.SetRoleForbidden.selector, 4)
        );
        keyperModule.setRole(Role.SUPER_SAFE, user, safeGroupA1, true);
    }

    // ? Org call removeGroup for a group of another org
    // Deploy 4 keyperSafes : following structure
    //           RootOrg1                    RootOrg2
    //              |                            |
    //           GroupA1                      GroupA2
    // Must Revert if RootOrg1 attempt to remove GroupA2
    function testRevertRemoveGroupFromAnotherOrg() public {
        (address orgAddr1, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);
        (address orgAddr2, address safeGroupA2) =
            setUpRootOrgAndOneGroup(org2Name, groupA2Name);

        vm.startPrank(orgAddr1);
        vm.expectRevert(
            KeyperModule.NotAuthorizedRemoveNonChildrenGroup.selector
        );
        keyperModule.removeGroup(orgAddr2, safeGroupA2);
        vm.stopPrank();

        vm.startPrank(orgAddr2);
        vm.expectRevert(
            KeyperModule.NotAuthorizedRemoveNonChildrenGroup.selector
        );
        keyperModule.removeGroup(orgAddr1, safeGroupA1);
    }

    function testRevertSetRolesToOrgNotRegistered() public {
        (, address safeGroupA1) = setUpRootOrgAndOneGroup(orgName, groupA1Name);

        address user = address(0xABCDE);

        vm.startPrank(safeGroupA1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.setRole(Role.SAFE_LEAD, user, safeGroupA1, true);
    }

    // ? Check disableSafeLeadRoles method success
    // groupA1 removed and it should not have any role
    function testRemoveGroupAndCheckDisables() public {
        (address orgAddr, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);

        (,,,, address superSafe) =
            keyperModule.getGroupInfo(orgAddr, safeGroupA1);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, safeGroupA1);
        assertEq(result, true);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safeGroupA1, uint8(Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafe, uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                superSafe, uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            ),
            false
        );
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg1                    RootOrg2
    //              |                            |
    //           safeGroupA1                      GroupA2
    // safeGroupA2 will be a safeLead of safeGroupA1
    function testModifyFromAnotherOrg() public {
        (address orgAddr1, address safeGroupA1) =
            setUpRootOrgAndOneGroup(orgName, groupA1Name);
        (, address safeGroupA2) = setUpRootOrgAndOneGroup(org2Name, groupA2Name);

        vm.startPrank(orgAddr1);
        keyperModule.setRole(Role.SAFE_LEAD, safeGroupA2, safeGroupA1, true);
        vm.stopPrank();

        assertEq(
            keyperModule.isSafeLead(orgAddr1, safeGroupA1, safeGroupA2), true
        );

        address[] memory groupA1Owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner = address(0xDEF);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(safeGroupA1), groupA1Owners[1]),
            true
        );

        vm.startPrank(safeGroupA2);

        keyperModule.addOwnerWithThreshold(
            newOwner, threshold, safeGroupA1, orgAddr1
        );
        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(safeGroupA1), newOwner), true
        );

        keyperModule.removeOwner(
            groupA1Owners[0], groupA1Owners[1], threshold, safeGroupA1, orgAddr1
        );
        assertEq(
            keyperModule.isSafeOwner(IGnosisSafe(safeGroupA1), groupA1Owners[1]),
            false
        );
    }

    // ! Reentrancy Attack test to execOnBehalf
    function testReentrancyAttack() public {

        (address orgAddr, address attacker, address victim) = setAttackerTree();
        gnosisHelper.updateSafeInterface(attacker);

        vm.startPrank(attacker);

        bytes memory emptyData;
        bytes memory signatures = attackerHelper.encodeSignaturesForAttackKeyperTx(
            attacker, victim, attacker, 5 gwei, emptyData, Enum.Operation(0)
        );

        bool result = attackerContract.performAttack(
            orgAddr,
            victim,
            attacker,
            5 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );

        assertEq(result, true);
        console.log("victim balance", attackerContract.getBalanceFromSafe(victim));
        console.log("attacker balance: ", attackerContract.getBalanceFromAttacker());
        // assertEq(attacker.balance, 100 gwei);
    }

    function setAttackerTree() public returns (address, address, address) {
        gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        address orgAddr = keyperSafes[orgName];

        gnosisHelper.updateSafeInterface(address(attackerAddr));
        string memory nameAttacker = "Attacker";
        keyperSafes[nameAttacker] = address(attackerAddr);

        address attacker = keyperSafes[nameAttacker];

        vm.startPrank(attacker);
        keyperModule.addGroup(orgAddr, orgAddr, nameAttacker);
        vm.stopPrank();

        address victim = gnosisHelper.newKeyperSafe(2, 1);
        string memory nameVictim = "Victim";
        keyperSafes[nameVictim] = address(victim);

        vm.startPrank(victim);
        keyperModule.addGroup(orgAddr, attacker, nameVictim);
        vm.stopPrank();

        vm.deal(victim, 100 gwei);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            Role.SAFE_LEAD, address(attacker), address(victim), true
        );
        vm.stopPrank();

        return (orgAddr, attacker, victim);
    }
}
