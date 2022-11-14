// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import {KeyperModule, IGnosisSafe, DenyHelper} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import {DenyHelper} from "../src/DenyHelper.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {console} from "forge-std/console.sol";

contract TestKeyperSafe is Test, SigningUtils, Constants {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRolesContract;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    address keyperRolesDeployed;

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;
    string orgName = "Main Org";
    string orgBName = "Second Org";
    string groupAName = "GroupA";
    string groupBName = "GroupB";
    string subGroupAName = "SubGroupA";
    string subSubGroupAName = "SubSubGroupA";

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
        assertEq(keyperRolesContract.doesUserHaveRole(safe, uint8(Role.ROOT_SAFE)), true);
    }

    // superSafe == org
    function testCreateGroupFromSafe() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        // Create new safe with setup called while creating contract
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        // Create Group calldata
        string memory groupName = groupAName;
        keyperSafes[groupName] = address(groupSafe);
        vm.label(keyperSafes[groupName], groupName);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupName);
        assertEq(result, true);

        (
            string memory name,
            address lead,
            address safe,
            address[] memory child,
            address superSafe
        ) = keyperModule.getGroupInfo(orgAddr, groupSafe);

        (, address orgLead,,,) = keyperModule.getOrg(orgAddr);

        assertEq(name, groupName);
        assertEq(lead, orgLead);
        assertEq(safe, groupSafe);
        assertEq(child.length, 0);
        assertEq(superSafe, orgAddr);
        assertEq(keyperRolesContract.doesUserHaveRole(orgAddr, uint8(Role.SUPER_SAFE)), true);
    }

    // superSafe != org
    function testCreateGroupFromSafeScenario2() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        (
            string memory name,
            address lead,
            address safe,
            address[] memory child,
            address superSafe
        ) = keyperModule.getGroupInfo(orgAddr, groupA);

        assertEq(name, groupAName);
        assertEq(lead, address(0));
        assertEq(safe, groupA);
        assertEq(child.length, 1);
        assertEq(child[0], subGroupA);
        assertEq(superSafe, orgAddr);

        (
            string memory nameSubGroup,
            address leadSubGroup,
            address safeSubGroup,
            address[] memory childSubGroup,
            address superSubGroup
        ) = keyperModule.getGroupInfo(orgAddr, subGroupA);

        assertEq(nameSubGroup, subGroupAName);
        assertEq(leadSubGroup, address(0));
        assertEq(safeSubGroup, subGroupA);
        assertEq(childSubGroup.length, 1);
        assertEq(superSubGroup, groupA);
    }

    function testRevertChildrenAlreadyExistAddGroup() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address subGroupSafe = gnosisHelper.newKeyperSafe(2, 1);
        string memory subGroupName = subGroupAName;
        keyperSafes[subGroupName] = address(subGroupSafe);

        bool result =
            gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupName);
        assertEq(result, true);

        vm.startPrank(subGroupSafe);
        vm.expectRevert(KeyperModule.ChildAlreadyExist.selector);
        keyperModule.addGroup(orgAddr, groupSafe, subGroupName);

        vm.deal(subGroupSafe, 1 ether);
        gnosisHelper.updateSafeInterface(subGroupSafe);

        vm.expectRevert();
        result = gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupName);
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           GroupA
    function setUpRootOrgAndOneGroup() public returns (address, address) {
        // Set initial safe as a rootOrg
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        // Create Group calldata
        string memory groupName = groupAName;
        keyperSafes[groupName] = address(groupSafe);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, groupName);

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

    function testLeadExecOnBehalf() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            groupSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
        assertEq(result, true);
        assertEq(receiver.balance, 2 gwei);
    }

    // When to == address(0)
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioOne()
        public
    {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address receiver = address(0xABC);
        address fakeReceiver = address(0);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            groupSafe,
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
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
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
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
        vm.startPrank(orgAddr);
        vm.expectRevert(DenyHelper.ZeroAddressProvided.selector);
        keyperModule.execTransactionOnBehalf(
            address(0),
            groupSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertInvalidGnosisSafeExecTransactionOnBehalf() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address receiver = address(0xABC);
        address fakeTargetSafe = address(0xFFE);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
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
    // SafeLead is an EOA
    function testRevertNotAuthorizedExecTransactionOnBehalf() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        // Random wallet instead of a safe
        address fakeCaller = address(0xFED);
        address receiver = address(0xABC);

        // Set safe_lead role to fake caller
        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, fakeCaller, orgAddr, true);
        vm.stopPrank();
        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        vm.startPrank(fakeCaller);
        vm.expectRevert(KeyperModule.NotAuthorizedExecOnBehalf.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            groupSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0),
            signatures
        );
    }

    function testRevertInvalidSignatureExecOnBehalf() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();
        address receiver = address(0xABC);

        // Try onbehalf with incorrect signers
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeInvalidSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );

        vm.expectRevert("GS026");
        // Execute invalid OnBehalf function
        vm.startPrank(orgAddr);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            groupSafe,
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
    //      GroupA   GroupB
    //        |
    //  SubGroupA
    //      |
    //  SubSubGroupA
    function setUpBaseOrgTree() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        // Create new safe with setup called while creating contract
        address safeGroupA = gnosisHelper.newKeyperSafe(3, 1);
        // Create AddGroup calldata
        string memory nameGroupA = groupAName;
        keyperSafes[nameGroupA] = address(safeGroupA);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, nameGroupA);

        // Create new safe with setup called while creating contract
        address safeGroupB = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        string memory nameGroupB = groupBName;
        keyperSafes[nameGroupB] = address(safeGroupB);

        orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, nameGroupB);

        // Create new safe with setup called while creating contract
        address safeSubGroupA = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        string memory nameSubGroupA = subGroupAName;
        keyperSafes[nameSubGroupA] = address(safeSubGroupA);
        orgAddr = keyperSafes[orgName];
        result =
            gnosisHelper.createAddGroupTx(orgAddr, safeGroupA, nameSubGroupA);

        // Create new safe with setup called while creating contract
        address safeSubSubGroupA = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        string memory nameSubSubGroupA = subSubGroupAName;
        keyperSafes[nameSubSubGroupA] = address(safeSubSubGroupA);
        orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(
            orgAddr, safeSubGroupA, nameSubSubGroupA
        );
    }

    function testSuperSafeExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        // Send ETH to group&subgroup
        vm.deal(groupA, 100 gwei);
        vm.deal(subGroupA, 100 gwei);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to groupA
        keyperHelper.setGnosisSafe(groupA);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA, subGroupA, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(groupA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            subGroupA,
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
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        // Send ETH to group&subgroup
        vm.deal(groupA, 100 gwei);
        vm.deal(subGroupA, 100 gwei);
        address receiver = address(0xABC);

        /// Enalbe allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableAllowlist(orgAddr);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to groupA
        keyperHelper.setGnosisSafe(groupA);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA, subGroupA, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(groupA);
        vm.expectRevert(DenyHelper.AddresNotAllowed.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            subGroupA,
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
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        // Send ETH to group&subgroup
        vm.deal(groupA, 100 gwei);
        vm.deal(subGroupA, 100 gwei);
        address[] memory receiver = new address[](1);
        receiver[0] = address(0xDDD);

        /// Enalbe allowlist
        vm.startPrank(orgAddr);
        keyperModule.enableDenylist(orgAddr);
        keyperModule.addToList(orgAddr, receiver);
        vm.stopPrank();

        // Set keyperhelper gnosis safe to groupA
        keyperHelper.setGnosisSafe(groupA);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            groupA, subGroupA, receiver[0], 2 gwei, emptyData, Enum.Operation(0)
        );

        // Execute on behalf function
        vm.startPrank(groupA);
        vm.expectRevert(DenyHelper.AddressDenied.selector);
        keyperModule.execTransactionOnBehalf(
            orgAddr,
            subGroupA,
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
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];
        address subSubGroupA = keyperSafes[subSubGroupAName];

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                orgAddr, uint8(Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(groupA, uint8(Role.SUPER_SAFE)),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                subGroupA, uint8(Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                subSubGroupA, uint8(Role.SUPER_SAFE)
            ),
            false
        );

        // Send ETH to org&subgroup
        vm.deal(orgAddr, 100 gwei);
        vm.deal(groupA, 100 gwei);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to subGroupA
        keyperHelper.setGnosisSafe(subGroupA);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            subGroupA, groupA, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );

        vm.expectRevert(KeyperModule.NotAuthorizedExecOnBehalf.selector);

        vm.startPrank(subGroupA);
        bool result = keyperModule.execTransactionOnBehalf(
            orgAddr,
            groupA,
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
        address groupA = keyperSafes[groupAName];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, groupA, true);

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
        address groupA = keyperSafes[groupAName];
        address userLeadModifyOwnersOnly = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(
            Role.SAFE_LEAD_MODIFY_OWNERS_ONLY,
            userLeadModifyOwnersOnly,
            groupA,
            true
        );
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(groupA);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        address[] memory prevOwnersList = gnosisHelper.gnosisSafe().getOwners();

        vm.startPrank(userLeadModifyOwnersOnly);
        address newOwner = address(0xaaaf);
        keyperModule.addOwnerWithThreshold(
            newOwner, threshold + 1, groupA, orgAddr
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
        address groupA = keyperSafes[groupAName];
        address userLead = address(0x123);

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, groupA, true);
        vm.stopPrank();

        gnosisHelper.updateSafeInterface(groupA);
        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.startPrank(userLead);
        keyperModule.removeOwner(prevOwner, owner, threshold, groupA, orgAddr);

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
        result = gnosisHelper.registerOrgTx(orgBName);
        keyperSafes[orgBName] = address(gnosisHelper.gnosisSafe());

        address orgAAddr = keyperSafes[orgName];
        address orgBAddr = keyperSafes[orgBName];

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();
        vm.expectRevert(KeyperModule.NotAuthorizedAsNotSafeLead.selector);

        vm.startPrank(orgBAddr);
        keyperModule.addOwnerWithThreshold(
            newOwnerOnOrgA, threshold, orgAAddr, orgAAddr
        );
    }

    function testRevertRootSafesToAttemptToRemoveFromExternalOrg() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(orgBName);
        keyperSafes[orgBName] = address(gnosisHelper.gnosisSafe());

        address orgAAddr = keyperSafes[orgName];
        address orgBAddr = keyperSafes[orgBName];

        address prevOwnerToRemoveOnOrgA =
            gnosisHelper.gnosisSafe().getOwners()[0];
        address ownerToRemove = gnosisHelper.gnosisSafe().getOwners()[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.expectRevert(KeyperModule.NotAuthorizedAsNotSafeLead.selector);

        vm.startPrank(orgBAddr);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA,
            ownerToRemove,
            threshold,
            orgAAddr,
            orgAAddr
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

    function testRemoveGroupFromOrg() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, groupA);
        assertEq(result, true);
        assertEq(keyperModule.isSuperSafe(orgAddr, orgAddr, groupA), false);

        // Check subGroupA is now a child of org
        assertEq(keyperModule.isChild(orgAddr, orgAddr, subGroupA), true);
        // Check org is parent of subGroupA
        assertEq(keyperModule.isSuperSafe(orgAddr, orgAddr, subGroupA), true);
    }

    /// removeGroup when org == superSafe
    function testRemoveGroupFromSafeOrgEqSuperSafe() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();
        // Create a sub safe
        address subSafeGroupA = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupAName] = address(subSafeGroupA);
        gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupAName);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, groupSafe);

        assertEq(result, true);

        result = keyperModule.isSuperSafe(orgAddr, orgAddr, groupSafe);
        assertEq(result, false);

        address[] memory child;
        (,,, child,) = keyperModule.getOrg(orgAddr);
        // Check removed group parent has subSafeGroup A as child an not groupSafe
        assertEq(child.length, 1);
        assertEq(child[0] == groupSafe, false);
        assertEq(child[0] == subSafeGroupA, true);
        assertEq(keyperModule.isChild(orgAddr, groupSafe, subSafeGroupA), false);
    }

    function testRevertSetRoleForbidden() public {

        (address orgAddr, address groupA1) = setUpRootOrgAndOneGroup();

        address user = address(0xABCDE);

        vm.startPrank(orgAddr);
        vm.expectRevert(abi.encodeWithSelector(KeyperModule.SetRoleForbidden.selector, 3));
        keyperModule.setRole(Role.ROOT_SAFE, user, groupA1, true);

        vm.expectRevert(abi.encodeWithSelector(KeyperModule.SetRoleForbidden.selector, 4));
        keyperModule.setRole(Role.SUPER_SAFE, user, groupA1, true);
    }

    function testRevertSetRolesToOrgNotRegistered() public {

        (, address groupA1) = setUpRootOrgAndOneGroup();

        address user = address(0xABCDE);

        vm.startPrank(groupA1);
        vm.expectRevert("UNAUTHORIZED");
        keyperModule.setRole(Role.SAFE_LEAD, user, groupA1, true);
    }
}
