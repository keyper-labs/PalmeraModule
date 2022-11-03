// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Constants} from "../src/Constants.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import "./GnosisSafeHelper.t.sol";

contract KeyperModuleTest is Test, Constants {
    GnosisSafeHelper gnosisHelper;
    KeyperModule keyperModule;

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

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModule(
            address(0x112233),
            address(0x445566),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        factory.deploy(salt, bytecode);
    }

    function testValidGnosisSafeAddressesOnConstructor() public {

        address fakeMasterCopyAddress = keyperModule.masterCopy();
        address fakeProxyFactoryAddress = keyperModule.proxyFactory();

        assertEq(keyperModule.isContract(fakeMasterCopyAddress), false);
        assertEq(keyperModule.isContract(fakeProxyFactoryAddress), false);
    }

    function testCreateRootOrg() public {
        registerOrgWithRoles(org1, rootOrgName);
        string memory orgname;
        address admin;
        address safe;
        address[] memory childs;
        address parent;
        (orgname, admin, safe, childs, parent) = keyperModule.getOrg(org1);
        assertEq(orgname, rootOrgName);
        assertEq(admin, org1);
        assertEq(safe, org1);
        assertEq(parent, address(0));
    }

    function testAddGroup() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        keyperModule.addGroup(org1, org1, "GroupA");
        string memory groupName;
        address admin;
        address safe;
        address[] memory childs;
        address parent;
        (groupName, admin, safe, childs, parent) =
            keyperModule.getGroupInfo(org1, groupA);
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(admin, org1);
        assertEq(parent, org1);
        assertEq(keyperModule.isChild(org1, org1, groupA), true);
    }

    function testExpectOrgNotRegistered() public {
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.OrgNotRegistered.selector);
        keyperModule.addGroup(org1, org1, "GroupA");
    }

    function testExpectParentNotRegistered() public {
        registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        vm.expectRevert(KeyperModule.ParentNotRegistered.selector);
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

    // Test is Parent function
    function testIsParent() public {
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
        assertEq(keyperModule.isParent(org1, org1, groupA), true);
        assertEq(keyperModule.isParent(org1, groupA, groupB), true);
        assertEq(keyperModule.isParent(org1, groupB, groupC), true);
        assertEq(keyperModule.isParent(org1, groupC, groupD), true);
        assertEq(keyperModule.isParent(org1, groupB, groupD), true);
        assertEq(keyperModule.isParent(org1, groupA, groupD), true);
        assertEq(keyperModule.isParent(org1, groupD, groupA), false);
        assertEq(keyperModule.isParent(org1, groupB, groupA), false);
    }

    // Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name) public {
        vm.startPrank(org);
        keyperModule.registerOrg(name);
        vm.stopPrank();
    }
}
