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

    address public keyperModuleAddr;
    address public keyperRolesDeployed;

    string public orgName = "Main Org";
    string public org2Name = "Second Org";
    string public groupA1Name = "GroupA1";
    string public groupA2Name = "GroupA2";
    string public groupBName = "GroupB";
    string public subGroupA1Name = "subGroupA1";
    string public subSubgroupA1Name = "SubSubGroupA";

    // Function called before each test is run
    function setUp() public {
        // Setup Gnosis Helper
        gnosisHelper = new GnosisSafeHelperV2();
        // Setup Gnosis Helper
        gnosisHelper.setupSafeEnv();

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
        (uint256 rootId,,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        DataTypes.Tier tier;
        string memory rootOrgName;
        address lead;
        address safe;
        uint256[] memory child;
        uint256 superSafe;
        (tier, rootOrgName, lead, safe, child, superSafe) =
            keyperModule.getGroupInfo(rootId);
        assertEq(uint256(tier), uint256(DataTypes.Tier.ROOT));
        assertEq(orgName, rootOrgName);
        assertEq(lead, address(0));
        assertEq(superSafe, 0);
    }

    function testAddGroupV2() public {
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        DataTypes.Tier tier;
        string memory groupName;
        address lead;
        uint256[] memory child;
        uint256 superSafe;
        (tier, groupName, lead,, child, superSafe) =
            keyperModule.getGroupInfo(groupIdA1);
        assertEq(uint256(tier), uint256(DataTypes.Tier.GROUP));
        assertEq(groupName, groupA1Name);
        assertEq(lead, address(0));
        assertEq(superSafe, rootId);
        (,,, address rootSafe,,) = keyperModule.getGroupInfo(rootId);
        assertEq(keyperModule.isRootSafeOf(rootSafe, groupIdA1), true);
        vm.stopPrank();
    }

    function testExpectInvalidGroupId() public {
        uint256 orgIdNotRegistered = 2;
        vm.expectRevert(Errors.InvalidGroupId.selector);
        keyperModule.addGroup(orgIdNotRegistered, groupA1Name);
    }

    function testExpectGroupNotRegistered() public {
        uint256 orgIdNotRegistered = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GroupNotRegistered.selector, orgIdNotRegistered
            )
        );
        keyperModule.addGroup(orgIdNotRegistered, groupA1Name);
    }

    function testAddSubGroup() public {
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        address groupBaddr = gnosisHelper.newKeyperSafe(4, 2);
        vm.startPrank(groupBaddr);
        uint256 groupIdB = keyperModule.addGroup(groupIdA1, groupBName);
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), true);
        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), true);
        assertEq(keyperModule.isTreeMember(groupIdA1, groupIdB), true);
        assertEq(keyperModule.isSuperSafe(groupIdA1, groupIdB), true);
    }

    function testTreeOrgsTreeMember() public {
        (uint256 rootId, uint256 groupIdA1, uint256 subGroupIdA1) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );
        assertEq(keyperModule.isTreeMember(rootId, groupIdA1), true);
        assertEq(keyperModule.isTreeMember(groupIdA1, subGroupIdA1), true);
        (uint256 rootId2, uint256 groupIdB,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(org2Name, groupBName);
        assertEq(keyperModule.isTreeMember(rootId2, groupIdB), true);
        assertEq(keyperModule.isTreeMember(rootId2, rootId), false);
        assertEq(keyperModule.isTreeMember(rootId2, groupIdA1), false);
        assertEq(keyperModule.isTreeMember(rootId, groupIdB), false);
    }

    // Test is SuperSafe function
    function testIsSuperSafeV2() public {
        (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 subGroupIdA1,
            uint256 subsubGroupIdA1
        ) = keyperSafeBuilder.setupOrgFourTiersTree(
            orgName, groupA1Name, subGroupA1Name, subSubgroupA1Name
        );
        assertEq(keyperModule.isSuperSafe(rootId, groupIdA1), true);
        assertEq(keyperModule.isSuperSafe(groupIdA1, subGroupIdA1), true);
        assertEq(keyperModule.isSuperSafe(subGroupIdA1, subsubGroupIdA1), true);
        assertEq(keyperModule.isSuperSafe(subsubGroupIdA1, subGroupIdA1), false);
        assertEq(keyperModule.isSuperSafe(subsubGroupIdA1, groupIdA1), false);
        assertEq(keyperModule.isSuperSafe(subsubGroupIdA1, rootId), false);
        assertEq(keyperModule.isSuperSafe(subGroupIdA1, groupIdA1), false);
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

    function testRevertUpdateSuperInvalidGroupIdV2() public {
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        // Get root info
        (,,, address rootSafe,,) = keyperModule.getGroupInfo(rootId);
        uint256 groupNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidGroupId.selector);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(groupIdA1, groupNotRegisteredId);
    }

    function testRevertUpdateSuperIfCallerIsNotSafeV2() public {
        (uint256 rootId, uint256 groupIdA1,) =
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
        (uint256 rootId, uint256 groupIdA1,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        (uint256 rootId2,,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(org2Name, groupBName);
        // Get root2 info
        (,,, address rootSafe2,,) = keyperModule.getGroupInfo(rootId2);
        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenGroup.selector);
        keyperModule.updateSuper(groupIdA1, rootId);
        vm.stopPrank();
    }
}
