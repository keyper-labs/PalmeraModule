// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
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

    address masterCopy;
    address safeFactory;

    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;
    string orgName = "Main Org";
    string orgBName = "Second Org";
    string groupAName = "GroupA";
    string groupBName = "GroupB";
    string subGroupAName = "SubGroupA";

    function setUp() public {
        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv(0);

        // setting keyperRoles Address
        gnosisHelper.setKeyperRoles(keyperRolesDeployed);

        // Init KeyperModule
        masterCopy = gnosisHelper.gnosisMasterCopy();
        safeFactory = address(gnosisHelper.safeFactory());

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
        (string memory name, address lead, address safe, address[] memory children, address superSafe) =
            keyperModule.getOrg(gnosisSafeAddr);
        assertEq(name, orgName);
        assertEq(lead, gnosisSafeAddr);
        assertEq(safe, gnosisSafeAddr);
        assertEq(superSafe, address(0));

        address child;
        for (uint256 i = 0; i < children.length; i++) {
            children[i] = child;
        }
        assertEq(child, address(0));
        assertEq(keyperModule.isOrgRegistered(gnosisSafeAddr), true);
    }

    // parent == org
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
    }

    // parent != org
    function testCreateGroupFromSafeScenario2() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        (
            string memory name, 
            address admin, 
            address safe, 
            address[] memory child, 
            address parent
        ) = keyperModule.getGroupInfo(orgAddr, groupA);

        assertEq(name, groupAName);
        assertEq(admin, orgAddr);
        assertEq(safe, groupA);
        assertEq(child.length, 1);
        assertEq(child[0], subGroupA);
        assertEq(parent, orgAddr);

        (
            string memory nameSubGroup, 
            address adminSubGroup, 
            address safeSubGroup, 
            address[] memory childrenSubGroup, 
            address parentSubGroup
        ) = keyperModule.getGroupInfo(orgAddr, subGroupA);

        assertEq(nameSubGroup, subGroupAName);
        assertEq(adminSubGroup, orgAddr);
        assertEq(safeSubGroup, subGroupA);
        assertEq(childrenSubGroup.length, 0);
        assertEq(parentSubGroup, groupA);
    }

    function testRevertChildAlreadyExistAddGroup() public {     

        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        address subGroupSafe = gnosisHelper.newKeyperSafe(2, 1);
        string memory subGroupName = subGroupAName;
        keyperSafes[subGroupName] = address(subGroupSafe);

        bool result = gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupName);
        assertEq(result, true);

        vm.startPrank(subGroupSafe);
        vm.expectRevert(KeyperModule.ChildAlreadyExist.selector);
        keyperModule.addGroup(orgAddr, groupSafe, subGroupName);

        // TODO: Until this point the test is working, so I must check why this
        // is not working with the following code: 
        // vm.deal(subGroupSafe, 100 gwei);
        // gnosisHelper.updateSafeInterface(subGroupSafe); 
        
        // vm.expectRevert(KeyperModule.ChildAlreadyExist.selector);
        // result = gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupName);
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           GroupA
    function setUpRootOrgAndOneGroup() public returns (address, address) {
        // Set initial safe as a rootOrg
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        // Create a safe
        address safeGroupA = gnosisHelper.newKeyperSafe(4, 2);
        string memory nameGroupA = groupAName;
        keyperSafes[nameGroupA] = address(safeGroupA);

        address orgAddr = keyperSafes[orgName];
        result = gnosisHelper.createAddGroupTx(orgAddr, orgAddr, nameGroupA);

        vm.deal(orgAddr, 100 gwei);
        vm.deal(safeGroupA, 100 gwei);

        return (orgAddr, safeGroupA);
    }

    function setAdminOfOrg() public returns (address, address) {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);
        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        address userLead = address(0x123);
        bool userEnabled = true;

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userLead, orgAddr, true);
        vm.stopPrank();

        return (orgAddr, userLead);
    }

    function testAdminExecOnBehalf() public {
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
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioOne() public {
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
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioTwo() public {
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
    function testRevertZeroAddressProvidedExecTransactionOnBehalfScenarioThree() public {
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

    function testRevertNotAuthorizedExecTransactionOnBehalf() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        // Random wallet instead of a safe
        address fakeCaller = address(0xFED);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function from a not authorized caller
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

    // TODO: @Cristian implement this usecases
    // function testSafeLeadExecOnBehalf()
    //                  --> Case 1: Lead is a Safe
    //                  --> Case 2: Lead is an EOA
    //                  --> Case 3: Lead is an EOA but tries to call the function for a group that he's not the lead
    // function testRootSafeExecOnBehalf
    // function testRevertExecOnBehalfNoRole

    function testRevertSuperSafeExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

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
        // Execute OnBehalf function with a safe that is not authorized
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

    function testIsUserAdminWithThreshold() public {
        (address orgAddr, address userAdmin) = setAdminOfOrg();

        assertEq(keyperModule.isSafeLead(orgAddr, orgAddr, userAdmin), true);

        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.startPrank(userAdmin);
        vm.expectRevert(KeyperModule.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(newOwner, threshold + 1, orgAddr, orgAddr);
    }

    // When threshold < 1
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioOne() public {
        (address orgAddr, address userAdmin) = setAdminOfOrg();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold = 0;

        vm.startPrank(userAdmin);
        vm.expectRevert(KeyperModule.InvalidThreshold.selector);
        keyperModule.addOwnerWithThreshold(newOwner, wrongThreshold, orgAddr, orgAddr);
    }

    // When threshold > (IGnosisSafe(targetSafe).getOwners().length.add(1))
    function testRevertInvalidThresholdAddOwnerWithThresholdScenarioTwo() public {

        (address orgAddr, address userAdmin) = setAdminOfOrg();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold = gnosisHelper.gnosisSafe().getOwners().length + 2;

        vm.startPrank(userAdmin);
        vm.expectRevert(KeyperModule.InvalidThreshold.selector);
        keyperModule.addOwnerWithThreshold(newOwner, wrongThreshold, orgAddr, orgAddr);
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
        address userAdmin = address(0x123);
        bool userEnabled = true;

        vm.startPrank(orgAddr);
        keyperModule.setRole(Role.SAFE_LEAD, userAdmin, orgAddr, true);
        vm.stopPrank();

        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address wrongOwnerToRemove = address(0xabdcf);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(ownersList.length, 3);

        vm.expectRevert(KeyperModule.OwnerNotFound.selector);

        vm.startPrank(userAdmin);
    
        keyperModule.removeOwner(prevOwner, wrongOwnerToRemove, threshold, orgAddr, orgAddr);
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
        bool result =
            gnosisHelper.createRemoveGroupTx(orgAddr, subSafeGroupA);

        assertEq(result, true);

        result = keyperModule.isSuperSafe(orgAddr, orgAddr, groupSafe);
        assertEq(result, false);

        address[] memory child;
        (,,, child,) = keyperModule.getGroupInfo(orgAddr, groupSafe);
        // Check removed group parent has not more child
        assertEq(child.length, 0);
        assertEq(keyperModule.isChild(orgAddr, groupSafe, subSafeGroupA), false);
    }

    // TODO : test following usecases
    // remove Group:
    // Usecases for revert from Remove group
    // -> Org call removeGRoup for a group of another org
    // -> Group call removeGroup for a group that is not his children
    // Role related usecases:
    // -> Check that the roles have been disabled for the group/org and for his safe lead

    // UseCases missing (similar usecase testRevert...) :
    // Create 2 Org: each with 1 group + 1 subgroup, then set a safe as safe_lead
    // then try with that safe to modify from another org

    // Add Tests that checks that this roles has been assigned following this rules
    // registerOrg => Give ROOT_SAFE role to safe registered
    // addGroup => Give SUPER_SAFE role to added safe
    // setRole(SAFE_LEAD,...., user) => Give SAFE_LEAD to role added
}
