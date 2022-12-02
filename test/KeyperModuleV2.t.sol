// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModuleV2} from "../src/KeyperModuleV2.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRolesV2} from "../src/KeyperRolesV2.sol";
import "./helpers/GnosisSafeHelperV2.t.sol";
import "./helpers/KeyperSafeBuilderV2.t.sol";
import {MockedContract} from "./mocks/MockedContract.t.sol";

contract KeyperModuleTestV2 is Test {
    GnosisSafeHelperV2 gnosisHelper;
    KeyperModuleV2 keyperModule;
    KeyperSafeBuilderV2 keyperSafeBuilder;

    MockedContract public masterCopyMocked;
    MockedContract public proxyFactoryMocked;

    address org1;
    address org2;
    address groupA;
    address groupB;
    address groupC;
    address groupD;
    address keyperModuleAddr;
    address keyperRolesDeployed;
    string rootOrgName;

    // TODO MOVE THIS
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string groupA1Name = "GroupA1";
    string groupA2Name = "GroupA2";
    string groupBName = "GroupB";
    string subGroupA1Name = "subGroupA1";
    string subSubgroupA1Name = "SubSubGroupA";

    // Function called before each test is run
    function setUp() public {
        // Setup Gnosis Helper
        gnosisHelper = new GnosisSafeHelperV2();
        // Setup of all Safe for Testing
        org1 = gnosisHelper.setupSafeEnv();
        org2 = gnosisHelper.setupSafeEnv();
        groupA = gnosisHelper.setupSafeEnv();
        groupB = gnosisHelper.setupSafeEnv();
        groupC = gnosisHelper.setupSafeEnv();
        groupD = gnosisHelper.setupSafeEnv();
        vm.label(org1, "Org 1");
        vm.label(org2, "Org 2");
        vm.label(groupA, "GroupA");
        vm.label(groupB, "GroupB");

        masterCopyMocked = new MockedContract();
        proxyFactoryMocked = new MockedContract();

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);

        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModuleV2(
            address(masterCopyMocked),
            address(proxyFactoryMocked),
            address(keyperRolesDeployed)
        );

        rootOrgName = "Root Org";

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode = abi.encodePacked(
            vm.getCode("KeyperRolesV2.sol:KeyperRolesV2"), args
        );

        factory.deploy(salt, bytecode);

        keyperSafeBuilder = new KeyperSafeBuilderV2();
        keyperSafeBuilder.setUpParams(
            KeyperModuleV2(keyperModule), GnosisSafeHelperV2(gnosisHelper)
        );
        gnosisHelper.setKeyperModule(keyperModuleAddr);
    }

    function testCreateRootOrg() public {
        uint256 orgId = registerOrgWithRoles(org1, rootOrgName);
        DataTypes.Tier tier;
        string memory orgname;
        address lead;
        address safe;
        uint256[] memory child;
        uint256 superSafe;
        (tier, orgname, lead, safe, child, superSafe) =
            keyperModule.getGroupInfo(orgId);
        assertEq(uint256(tier), uint256(DataTypes.Tier.ROOT));
        assertEq(orgname, rootOrgName);
        assertEq(lead, address(0));
        assertEq(safe, org1);
        assertEq(superSafe, 0);
    }

    function testAddGroupV2() public {
        uint256 orgId = registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        uint256 groupIdA = keyperModule.addGroup(orgId, "GroupA");
        DataTypes.Tier tier;
        string memory groupName;
        address lead;
        address safe;
        uint256[] memory child;
        uint256 superSafe;
        (tier, groupName, lead, safe, child, superSafe) =
            keyperModule.getGroupInfo(groupIdA);
        assertEq(uint256(tier), uint256(DataTypes.Tier.GROUP));
        assertEq(groupName, "GroupA");
        assertEq(safe, groupA);
        assertEq(lead, address(0));
        assertEq(superSafe, orgId);
        // TODO update with isSuperSafe function
        assertEq(keyperModule.isRootSafeOf(org1, groupIdA), true);
        vm.stopPrank();
    }

    function testExpectInvalidGroupId() public {
        uint256 orgIdNotRegistered = 2;
        vm.startPrank(groupA);
        vm.expectRevert(Errors.InvalidGroupId.selector);
        keyperModule.addGroup(orgIdNotRegistered, "GroupA");
    }

    function testExpectGroupNotRegistered() public {
        uint256 orgIdNotRegistered = 1;
        vm.startPrank(groupA);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GroupNotRegistered.selector, orgIdNotRegistered
            )
        );
        keyperModule.addGroup(orgIdNotRegistered, "GroupA");
    }

    function testAddSubGroup() public {
        uint256 orgId = registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        uint256 groupIdA = keyperModule.addGroup(orgId, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        uint256 groupIdB = keyperModule.addGroup(groupIdA, "Group B");
        assertEq(keyperModule.isTreeMember(orgId, groupIdA), true);
        assertEq(keyperModule.isSuperSafe(orgId, groupIdA), true);
        assertEq(keyperModule.isTreeMember(groupIdA, groupIdB), true);
        assertEq(keyperModule.isSuperSafe(groupIdA, groupIdB), true);
    }

    // Test tree structure for groups
    //                  org1        org2
    //                  |            |
    //              groupA          groupB
    //                |
    //              groupC
    function testTreeOrgs() public {
        uint256 orgId = registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        uint256 groupIdA = keyperModule.addGroup(orgId, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupC);
        uint256 groupIdC = keyperModule.addGroup(groupIdA, "GroupC");
        // TODO update with isSuperSafe function
        assertEq(keyperModule.isTreeMember(orgId, groupIdA), true);
        assertEq(keyperModule.isTreeMember(groupIdA, groupIdC), true);
        vm.stopPrank();
        uint256 orgId2 = registerOrgWithRoles(org2, "RootOrg2");
        vm.startPrank(groupB);
        uint256 groupIdB = keyperModule.addGroup(orgId2, "GroupB");
        assertEq(keyperModule.isTreeMember(orgId2, groupIdB), true);
    }

    // // Test transaction execution

    // // Test is SuperSafe function
    function testIsSuperSafeV2() public {
        uint256 orgId = registerOrgWithRoles(org1, rootOrgName);
        vm.startPrank(groupA);
        uint256 groupIdA = keyperModule.addGroup(orgId, "GroupA");
        vm.stopPrank();
        vm.startPrank(groupB);
        uint256 groupIdB = keyperModule.addGroup(groupIdA, "GroupB");
        vm.stopPrank();
        vm.startPrank(groupC);
        uint256 groupIdC = keyperModule.addGroup(groupIdB, "GroupC");
        vm.stopPrank();
        vm.startPrank(groupD);
        uint256 groupIdD = keyperModule.addGroup(groupIdC, "groupD");
        assertEq(keyperModule.isSuperSafe(orgId, groupIdA), true);
        assertEq(keyperModule.isSuperSafe(groupIdA, groupIdB), true);
        assertEq(keyperModule.isSuperSafe(groupIdB, groupIdC), true);
        assertEq(keyperModule.isSuperSafe(groupIdC, groupIdD), true);
        assertEq(keyperModule.isSuperSafe(groupIdB, groupIdD), false);
        assertEq(keyperModule.isSuperSafe(groupIdA, groupIdD), false);
        assertEq(keyperModule.isSuperSafe(groupIdD, groupIdA), false);
        assertEq(keyperModule.isSuperSafe(groupIdD, groupIdB), false);
        assertEq(keyperModule.isSuperSafe(groupIdB, groupIdA), false);
    }

    function testUpdateSuperV2() public {
        (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 groupIdB,
            uint256 subGroupIdA1,
            uint256 subsubGroupIdA1
        ) = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, groupA1Name, groupBName, subGroupA1Name, subSubgroupA1Name
        );
        (,,, address rootSafe,,) = keyperModule.getGroupInfo(rootId);
        (,,, address groupA1,,) = keyperModule.getGroupInfo(groupIdA1);
        (,,, address groupBB,,) = keyperModule.getGroupInfo(groupIdB);
        (,,, address subGroupA1,,) = keyperModule.getGroupInfo(subGroupIdA1);

        KeyperRolesV2 authority = KeyperRolesV2(keyperRolesDeployed);
        assertEq(
            authority.doesUserHaveRole(
                groupA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            authority.doesUserHaveRole(
                groupBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            authority.doesUserHaveRole(
                subGroupA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(keyperModule.isTreeMember(rootId, subGroupIdA1), true);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(subGroupIdA1, groupIdB);
        vm.stopPrank();
        assertEq(keyperModule.isSuperSafe(groupIdB, subGroupIdA1), true);
        assertEq(keyperModule.isSuperSafe(groupIdA1, subGroupIdA1), false);
        assertEq(keyperModule.isSuperSafe(groupIdA1, subGroupIdA1), false);
        assertEq(keyperModule.isSuperSafe(groupIdA1, subsubGroupIdA1), false);
        assertEq(keyperModule.isTreeMember(groupIdA1, subsubGroupIdA1), false);
        assertEq(keyperModule.isTreeMember(groupIdB, subsubGroupIdA1), true);
        assertEq(
            authority.doesUserHaveRole(
                groupA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            authority.doesUserHaveRole(
                groupBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    // TODO This test does not make much sense with the current implementation: Review it
    // function testRevertUpdateSuperIfActualGroupNotRegisteredV2() public {
    //     (uint256 rootId, uint256 groupIdA1) =
    //         keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
    //     // Get root info
    //     (,,, address rootSafe,,) = keyperModule.getGroupInfo(rootId);
    //     uint256 groupNotRegisteredId = 6;
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             Errors.GroupNotRegistered.selector, groupNotRegisteredId
    //         )
    //     );
    //     vm.startPrank(rootSafe);
    //     keyperModule.updateSuper(groupIdA1, groupNotRegisteredId);
    // }

    function testRevertUpdateSuperInvalidGroupIdV2() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        // Get root info
        (,,, address rootSafe,,) = keyperModule.getGroupInfo(rootId);
        uint256 groupNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidGroupId.selector);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(groupIdA1, groupNotRegisteredId);
    }

    function testRevertUpdateSuperIfCallerIsNotSafeV2() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        vm.startPrank(address(0xDDD));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidGnosisSafe.selector, address(0xDDD)
            )
        );
        keyperModule.updateSuper(groupIdA1, rootId);
        vm.stopPrank();
    }

    function testRevertUpdateSuperIfCallerNotPartofTheOrgV2() public {
        (, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        (uint256 rootId2,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(org2Name, groupBName);
        // Get root2 info
        (,,, address rootSafe2,,) = keyperModule.getGroupInfo(rootId2);

        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenGroup.selector);
        keyperModule.updateSuper(rootId2, groupIdA1);
        vm.stopPrank();
    }

    // Register org call with mocked call to KeyperRoles
    function registerOrgWithRoles(address org, string memory name)
        public
        returns (uint256 orgId)
    {
        vm.startPrank(org);
        orgId = keyperModule.registerOrg(name);
        vm.stopPrank();
        return orgId;
    }
}
