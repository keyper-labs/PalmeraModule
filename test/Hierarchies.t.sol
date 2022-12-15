// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {KeyperModule} from "../src/KeyperModule.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";
import "./helpers/GnosisSafeHelper.t.sol";
import "./helpers/KeyperSafeBuilder.t.sol";
import {MockedContract} from "./mocks/MockedContract.t.sol";

contract Hierarchies is Test {
    GnosisSafeHelper gnosisHelper;
    KeyperModule keyperModule;
    KeyperSafeBuilder keyperSafeBuilder;
    KeyperRoles keyperRolesContract;

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
        gnosisHelper = new GnosisSafeHelper();
        // Setup Gnosis Helper
        gnosisHelper.setupSafeEnv();

        masterCopyMocked = new MockedContract();
        proxyFactoryMocked = new MockedContract();

        CREATE3Factory factory = new CREATE3Factory();
        bytes32 salt = keccak256(abi.encode(0xafff));
        // Predict the future address of keyper roles
        keyperRolesDeployed = factory.getDeployed(address(this), salt);
        keyperRolesContract = KeyperRoles(keyperRolesDeployed);

        // Gnosis safe call are not used during the tests, no need deployed factory/mastercopy
        keyperModule = new KeyperModule(
            address(masterCopyMocked),
            address(proxyFactoryMocked),
            address(keyperRolesDeployed)
        );

        keyperModuleAddr = address(keyperModule);

        bytes memory args = abi.encode(address(keyperModuleAddr));

        bytes memory bytecode =
            abi.encodePacked(vm.getCode("KeyperRoles.sol:KeyperRoles"), args);

        factory.deploy(salt, bytecode);

        keyperSafeBuilder = new KeyperSafeBuilder();
        keyperSafeBuilder.setUpParams(
            KeyperModule(keyperModule), GnosisSafeHelper(gnosisHelper)
        );
        gnosisHelper.setKeyperModule(keyperModuleAddr);
    }

    function testRegisterRootOrg() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        assertEq(result, true);
        bytes32 orgHash =
            keyperModule.getOrgHashBySafe(address(gnosisHelper.gnosisSafe()));
        assertEq(orgHash, keccak256(abi.encodePacked(orgName)));
        uint256 rootId = keyperModule.getGroupIdBySafe(
            orgHash, address(gnosisHelper.gnosisSafe())
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
        assertEq(safe, address(gnosisHelper.gnosisSafe()));
        assertEq(superSafe, 0);
        assertEq(child.length, 0);
        assertEq(keyperModule.isOrgRegistered(orgHash), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                safe, uint8(DataTypes.Role.ROOT_SAFE)
            ),
            true
        );
    }

    function testAddGroup() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        (
            DataTypes.Tier tier,
            string memory groupName,
            address lead,
            address safe,
            uint256[] memory child,
            uint256 superSafe
        ) = keyperModule.getGroupInfo(groupIdA1);

        assertEq(uint256(tier), uint256(DataTypes.Tier.GROUP));
        assertEq(groupName, groupA1Name);
        assertEq(lead, address(0));
        assertEq(safe, address(gnosisHelper.gnosisSafe()));
        assertEq(child.length, 0);
        assertEq(superSafe, rootId);

        address groupAddr = keyperModule.getGroupSafeAddress(groupIdA1);
        address rootAddr = keyperModule.getGroupSafeAddress(rootId);

        assertEq(keyperModule.isRootSafeOf(rootAddr, groupIdA1), true);
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                rootAddr, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
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
        (uint256 rootId, uint256 groupIdA1) =
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
        (uint256 rootId2, uint256 groupIdB) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(org2Name, groupBName);
        assertEq(keyperModule.isTreeMember(rootId2, groupIdB), true);
        assertEq(keyperModule.isTreeMember(rootId2, rootId), false);
        assertEq(keyperModule.isTreeMember(rootId2, groupIdA1), false);
        assertEq(keyperModule.isTreeMember(rootId, groupIdB), false);
    }

    // Test is SuperSafe function
    function testIsSuperSafe() public {
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

    function testUpdateSuper() public {
        (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 groupIdB,
            uint256 subGroupIdA1,
            uint256 subsubGroupIdA1
        ) = keyperSafeBuilder.setUpBaseOrgTree(
            orgName, groupA1Name, groupBName, subGroupA1Name, subSubgroupA1Name
        );
        address rootSafe = keyperModule.getGroupSafeAddress(rootId);
        address groupA1 = keyperModule.getGroupSafeAddress(groupIdA1);
        address groupBB = keyperModule.getGroupSafeAddress(groupIdB);
        address subGroupA1 = keyperModule.getGroupSafeAddress(subGroupIdA1);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
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
            keyperRolesContract.doesUserHaveRole(
                groupA1, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            false
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                groupBB, uint8(DataTypes.Role.SUPER_SAFE)
            ),
            true
        );
    }

    function testRevertUpdateSuperInvalidGroupId() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        // Get root info
        address rootSafe = keyperModule.getGroupSafeAddress(rootId);

        uint256 groupNotRegisteredId = 6;
        vm.expectRevert(Errors.InvalidGroupId.selector);
        vm.startPrank(rootSafe);
        keyperModule.updateSuper(groupIdA1, groupNotRegisteredId);
    }

    function testRevertUpdateSuperIfCallerIsNotSafe() public {
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

    function testRevertUpdateSuperIfCallerNotPartofTheOrg() public {
        (uint256 rootId, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);
        (uint256 rootId2,) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(org2Name, groupBName);
        // Get root2 info
        address rootSafe2 = keyperModule.getGroupSafeAddress(rootId2);
        vm.startPrank(rootSafe2);
        vm.expectRevert(Errors.NotAuthorizedUpdateNonChildrenGroup.selector);
        keyperModule.updateSuper(groupIdA1, rootId);
        vm.stopPrank();
    }

    function testCreateGroupThreeTiersTree() public {
        (uint256 orgRootId, uint256 safeGroupA1Id, uint256 safeSubGroupA1Id) =
        keyperSafeBuilder.setupOrgThreeTiersTree(
            orgName, groupA1Name, subGroupA1Name
        );

        address safeGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeGroupA1Id);
        address safeSubGroupA1Addr =
            keyperModule.getGroupSafeAddress(safeSubGroupA1Id);

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

    // Revert ChildAlreadyExist() addGroup (Attempting to add a group when its child already exist)
    // Caller: safeSubGroupA1
    // Caller Type: safe
    // Caller Role: N/A
    // TargerSafe: safeGroupA1
    // TargetSafe Type: safe
    function testRevertGroupAlreadyRegisteredAddGroup() public {
        (, uint256 groupIdA1) =
            keyperSafeBuilder.setupRootOrgAndOneGroup(orgName, groupA1Name);

        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
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
}
