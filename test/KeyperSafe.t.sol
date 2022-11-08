// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
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
        (string memory name, address lead, address safe,, address superSafe) =
            keyperModule.getOrg(gnosisSafeAddr);
        assertEq(name, orgName);
        assertEq(lead, gnosisSafeAddr);
        assertEq(safe, gnosisSafeAddr);
        assertEq(superSafe, address(0));
    }

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

    function testRevertChildAlreadyExistAddGroup() public {
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

        // TODO: Until this point the test is working, so I must check why this
        // is not working with the following code:
        // vm.deal(subGroupSafe, 100 gwei);
        // gnosisHelper.updateSafeInterface(subGroupSafe);

        // vm.expectRevert(KeyperModule.ChildAlreadyExist.selector);
        // result = gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupName);
    }

    function testLeadExecOnBehalf() public {
        // Set initialsafe as org
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
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
        keyperHelper.setGnosisSafe(orgAddr);
        bytes memory emptyData;
        bytes memory signatures = keyperHelper.encodeSignaturesKeyperTx(
            orgAddr, groupSafe, receiver, 2 gwei, emptyData, Enum.Operation(0)
        );
        // Execute on behalf function
        vm.startPrank(orgAddr);
        result = keyperModule.execTransactionOnBehalf(
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

    function testRevertInvalidSignatureExecOnBehalf() public {
        // Set initialsafe as org
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
        result = keyperModule.execTransactionOnBehalf(
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

		// Create new safe with setup called while creating contract
        address safeSubSubGroupA = gnosisHelper.newKeyperSafe(2, 1);
        // Create AddGroup calldata
        string memory nameSubSubGroupA = subSubGroupAName;
        keyperSafes[nameSubSubGroupA] = address(safeSubSubGroupA);
        orgAddr = keyperSafes[orgName];
        result =
            gnosisHelper.createAddGroupTx(orgAddr, safeSubGroupA, nameSubSubGroupA);
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

        // Check sub safe is a child of org
        address[] memory newChild;
        (,,, newChild,) = keyperModule.getOrg(orgAddr);
        assertEq(newChild[0], subSafeGroupA);
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
