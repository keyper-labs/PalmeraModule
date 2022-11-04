// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Constants} from "../src/Constants.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import "./GnosisSafeHelper.t.sol";
import {MockedContractA, MockedContractB} from "./MockedContract.t.sol";

contract KeyperModuleTest is Test, Constants {
    GnosisSafeHelper gnosisHelper;
    KeyperModule keyperModule;

    MockedContractA public mockedContractA;
    MockedContractB public mockedContractB;

    address org1;
    address org2;
    address groupA;
    address groupB;
    address groupC;
    address groupD;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    string rootOrgName;

    // Function called before each test is run
    function setUp() public {
        // Setup Gnosis Helper
        gnosisHelper = new GnosisSafeHelper();
        // Setup of all Safe for Testing
        org1 = gnosisHelper.setupSafeEnv(0);
        org2 = gnosisHelper.setupSafeEnv(1);
        groupA = gnosisHelper.setupSafeEnv(2);
        groupB = gnosisHelper.setupSafeEnv(3);
        groupC = gnosisHelper.setupSafeEnv(4);
        groupD = gnosisHelper.setupSafeEnv(5);
        vm.label(org1, "Org 1");
        vm.label(groupA, "GroupA");
        vm.label(groupB, "GroupB");

        mockedContractA = new MockedContractA();
        mockedContractB = new MockedContractB();

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModule(
            address(mockedContractA),
            address(mockedContractB),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        factory.deploy(salt, bytecode);
    }

    function testCreateRootOrg() public {
        registerOrgWithRoles(org1, rootOrgName);
        string memory orgname;
        address lead;
        address safe;
        address[] memory child;
        address superSafe;
        (orgname, lead, safe, child, superSafe) = keyperModule.getOrg(org1);
        assertEq(orgname, rootOrgName);
        assertEq(lead, org1);
        assertEq(safe, org1);
        assertEq(superSafe, address(0));
    }

    function testAddGroup() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        string memory groupName;
        address lead;
        address safe;
        address[] memory child;
        address superSafe;
        (groupName, lead, safe, child, superSafe) =
            keyperModule.getGroupInfo(org1, groupA);
        (, address orgLead,,,) = keyperModule.getOrg(org1);
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(lead, orgLead);
        assertEq(superSafe, org1);
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
    }

    function testExpectOrgNotRegistered() public {
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.OrgNotRegistered.selector);
        keyperModule.addGroup(org1, org1, "GroupA");
    }

    function testExpectSuperSafeNotRegistered() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.SuperSafeNotRegistered.selector);
        keyperModule.addGroup(org1, groupA, "GroupA");
    }

    function testAddSubGroup() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        keyperModule.addGroup(org1, groupA, "Group B");
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
        assertEq(keyperModule.isChild(org1, groupA, groupB), true);
    }

    // Test tree structure for groups
    //                  org1        org2
    //                  |            |
    //              groupA          groupB
    //                |
    //              groupC
    function testTreeOrgs() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupC);
        keyperModule.addGroup(org1, groupA, "Group C");
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
        assertEq(keyperModule.isChild(org1, groupA, groupC), true);
        vm.stopPrank();
        registerOrgWithRoles(org2, "RootOrg2");
        vm.startPrank(groupB);
        keyperModule.addGroup(org2, org2, "GroupB");
        assertEq(keyperModule.isChild(org2, org2, groupB), true);
    }

    // Test transaction execution
    function testExecKeeperTransaction() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(org1);
        keyperModule.addGroup(org1, org1, "GroupA");
    }

    // Test is SuperSafe function
    function testIsSuperSafe() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        keyperModule.addGroup(org1, groupA, "groupB");
        vm.stopPrank();
        vm.startPrank(groupC);
        keyperModule.addGroup(org1, groupB, "GroupC");
        vm.stopPrank();
        vm.startPrank(groupD);
        keyperModule.addGroup(org1, groupC, "groupD");
        assertEq(keyperModule.isSuperSafe(org1, org1, groupA), true);
        assertEq(keyperModule.isSuperSafe(org1, groupA, groupB), true);
        assertEq(keyperModule.isSuperSafe(org1, groupB, groupC), true);
        assertEq(keyperModule.isSuperSafe(org1, groupC, groupD), true);
        assertEq(keyperModule.isSuperSafe(org1, groupB, groupD), true);
        assertEq(keyperModule.isSuperSafe(org1, groupA, groupD), true);
        assertEq(keyperModule.isSuperSafe(org1, groupD, groupA), false);
        assertEq(keyperModule.isSuperSafe(org1, groupB, groupA), false);
    }

    // Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name) public {
        vm.startPrank(org);
        keyperModule.registerOrg(name);
        vm.stopPrank();
    }
}
