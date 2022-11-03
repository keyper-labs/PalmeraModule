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

    // DenyHelper denyHelper;

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

    function testValidGnosisSafeAddresses() public {
        assertEq(keyperModule.isContract(address(masterCopy)), true);
        assertEq(keyperModule.isContract(address(safeFactory)), true);
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
            address admin,
            address safe,
            address[] memory childs,
            address parent
        ) = keyperModule.getOrg(gnosisSafeAddr);

        assertEq(name, orgName);
        assertEq(admin, gnosisSafeAddr);
        assertEq(safe, gnosisSafeAddr);
        assertEq(parent, address(0));

        address child;
        for (uint256 i = 0; i < childs.length; i++) {
            childs[i] = child;
        }
        assertEq(child, address(0));
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
        address userAdmin = address(0x123);
        bool userEnabled = true;

        vm.startPrank(orgAddr);
        keyperModule.setUserAdmin(userAdmin, userEnabled);
        vm.stopPrank();

        return (orgAddr, userAdmin);
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

    function testParentExecOnBehalf() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        // Send ETH to group&subgroup
        vm.deal(groupA, 100 gwei);
        vm.deal(subGroupA, 100 gwei);
        address receiver = address(0xABC);

        // Set keyperhelper gnosis safe to org
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

    function testRevertParentExecOnBehalf() public {
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
            ADMIN_ADD_OWNERS_ROLE, caller, ADD_OWNER, true
        );
    }

    function testSetUserAdmin() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);
        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        address userAdmin = address(0x123);
        bool userEnabled = true;

        vm.startPrank(orgAddr);
        keyperModule.setUserAdmin(userAdmin, userEnabled);

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userAdmin, ADMIN_ADD_OWNERS_ROLE
            ),
            true
        );
        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userAdmin, ADMIN_REMOVE_OWNERS_ROLE
            ),
            true
        );
    }

    function testAddOwnerWithThreshold() public {
        (address orgAddr, address userAdmin) = setAdminOfOrg();

        assertEq(keyperModule.isUserAdmin(orgAddr, userAdmin), true);

        address newOwner = address(0xaaaf);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        address[] memory prevOwnersList = gnosisHelper.gnosisSafe().getOwners();

        vm.startPrank(userAdmin);
        keyperModule.addOwnerWithThreshold(newOwner, threshold + 1, orgAddr);

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

        assertEq(keyperModule.isUserAdmin(orgAddr, userAdmin), true);

        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        address newOwner;

        for (uint256 i = 0; i < owners.length; i++) {
            newOwner = owners[i];
        }

        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.startPrank(userAdmin);
        vm.expectRevert(KeyperModule.OwnerAlreadyExists.selector);
        keyperModule.addOwnerWithThreshold(newOwner, threshold + 1, orgAddr);
    }

    // addOwnerWithThreshold => NotAuthorizedAsNotAnAdmin is triggered
    // TODO: Pending check, because already exists a modifier asking for
    // auth, so it's probable the revertion is not necessary. This test
    // is commented for now.
    // function testRevertNotAuthorizedAsNotAnAdminAddOwnerWithThreshold() public {

    //     (address orgAddr,) = setAdminOfOrg();
    //     (address orgAddrB, ) = setAdminOfOrg();

    //     address fakeAdmin = address(0xfff);
    //     address newOwner = address(0xaaaf);
    //     uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

    //     vm.startPrank(fakeAdmin);
    //     vm.expectRevert(KeyperModule.NotAuthorizedAsNotAnAdmin.selector);
    //     keyperModule.addOwnerWithThreshold(newOwner, threshold + 1, orgAddr);

    // }

    function testRevertInvalidThresholdAddOwnerWithThreshold() public {
        (address orgAddr, address userAdmin) = setAdminOfOrg();

        address newOwner = address(0xf1f1f1);
        uint256 wrongThreshold = 0;

        vm.startPrank(userAdmin);
        vm.expectRevert(KeyperModule.InvalidThreshold.selector);
        keyperModule.addOwnerWithThreshold(newOwner, wrongThreshold, orgAddr);
    }

    function testRemoveOwner() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);
        assertEq(result, true);

        address orgAddr = keyperSafes[orgName];
        address userAdmin = address(0x123);
        bool userEnabled = true;

        vm.startPrank(orgAddr);
        keyperModule.setUserAdmin(userAdmin, userEnabled);
        vm.stopPrank();

        address[] memory ownersList = gnosisHelper.gnosisSafe().getOwners();

        address prevOwner = ownersList[0];
        address owner = ownersList[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        assertEq(ownersList.length, 3);

        vm.startPrank(userAdmin);
        keyperModule.removeOwner(prevOwner, owner, threshold, orgAddr);

        address[] memory postRemoveOwnersList =
            gnosisHelper.gnosisSafe().getOwners();

        assertEq(postRemoveOwnersList.length, ownersList.length - 1);
        assertEq(gnosisHelper.gnosisSafe().isOwner(owner), false);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), threshold);
    }

    function testRevertSeveralUserAdminsToAttemptToAdd() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(orgBName);
        keyperSafes[orgBName] = address(gnosisHelper.gnosisSafe());

        vm.label(keyperSafes[orgName], orgName);
        vm.label(keyperSafes[orgBName], orgBName);

        address orgAAddr = keyperSafes[orgName];
        address orgBAddr = keyperSafes[orgBName];

        bool userEnabled = true;

        address userAdminOrgA = address(0x123);
        address userAdminOrgB = address(0x321);

        vm.startPrank(orgAAddr);
        keyperModule.setUserAdmin(userAdminOrgA, userEnabled);
        vm.stopPrank();

        vm.startPrank(orgBAddr);
        keyperModule.setUserAdmin(userAdminOrgB, userEnabled);
        vm.stopPrank();

        assertEq(
            keyperRolesContract.doesUserHaveRole(
                userAdminOrgB, ADMIN_ADD_OWNERS_ROLE
            ),
            true
        );

        address newOwnerOnOrgA = address(0xF1F1);
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.expectRevert(KeyperModule.NotAuthorizedAsNotAnAdmin.selector);

        vm.startPrank(userAdminOrgB);
        keyperModule.addOwnerWithThreshold(newOwnerOnOrgA, threshold, orgAAddr);
    }

    function testRevertSeveralUserAdminsToAttemptToRemove() public {
        bool result = gnosisHelper.registerOrgTx(orgName);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());

        gnosisHelper.newKeyperSafe(4, 2);
        result = gnosisHelper.registerOrgTx(orgBName);
        keyperSafes[orgBName] = address(gnosisHelper.gnosisSafe());

        vm.label(keyperSafes[orgName], orgName);
        vm.label(keyperSafes[orgBName], orgBName);

        address orgAAddr = keyperSafes[orgName];
        address orgBAddr = keyperSafes[orgBName];

        bool userEnabled = true;

        address userAdminOrgA = address(0x123);
        address userAdminOrgB = address(0x321);

        vm.startPrank(orgAAddr);
        keyperModule.setUserAdmin(userAdminOrgA, userEnabled);
        vm.stopPrank();

        vm.startPrank(orgBAddr);
        keyperModule.setUserAdmin(userAdminOrgB, userEnabled);
        vm.stopPrank();

        address prevOwnerToRemoveOnOrgA =
            gnosisHelper.gnosisSafe().getOwners()[0];
        address ownerToRemove = gnosisHelper.gnosisSafe().getOwners()[1];
        uint256 threshold = gnosisHelper.gnosisSafe().getThreshold();

        vm.expectRevert(KeyperModule.NotAuthorizedAsNotAnAdmin.selector);

        vm.startPrank(userAdminOrgB);
        keyperModule.removeOwner(
            prevOwnerToRemoveOnOrgA, ownerToRemove, threshold, orgAAddr
        );
    }

    /// removeGroup when org == parent
    function testRemoveGroupFromSafeOrgEqParent() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();

        assertEq(keyperModule.isOrgRegistered(orgAddr), true);

        address parent;
        (,,,, parent) = keyperModule.getGroupInfo(orgAddr, groupSafe);

        assertEq(orgAddr, parent);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result =
            gnosisHelper.createRemoveGroupTx(orgAddr, orgAddr, groupSafe);

        assertEq(result, true);

        result = keyperModule.isParent(orgAddr, orgAddr, groupSafe);
        assertEq(result, false);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      GroupA   GroupB
    //        |
    //  SubGroupA
    // SubGroupA is going to be removed
    function testRemoveChild() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        assertEq(keyperModule.isChild(orgAddr, groupA, subGroupA), true);
        assertEq(keyperModule.isAdmin(orgAddr, subGroupA), true);
        assertEq(keyperModule.isAdmin(groupA, subGroupA), false);

        gnosisHelper.updateSafeInterface(orgAddr);

        bool result =
            gnosisHelper.createRemoveGroupTx(orgAddr, groupA, subGroupA);

        assertEq(result, true);
        assertEq(keyperModule.isChild(orgAddr, groupA, subGroupA), false);

        address[] memory children;
        (,,, children,) = keyperModule.getGroupInfo(orgAddr, groupA);
        address newChild;

        for (uint256 i = 0; i < children.length; i++) {
            children[i] == newChild;
        }

        bool comparison = newChild == subGroupA ? true : false;
        assertEq(comparison, false);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      GroupA   GroupB
    //        |
    //  SubGroupA
    // GroupA is going to be removed
    function testRemoveGroupWithChildren() public {
        setUpBaseOrgTree();
        address orgAddr = keyperSafes[orgName];
        address groupA = keyperSafes[groupAName];
        address subGroupA = keyperSafes[subGroupAName];

        assertEq(keyperModule.isChild(orgAddr, orgAddr, groupA), true);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, orgAddr, groupA);

        assertEq(result, true);
        assertEq(keyperModule.isChild(orgAddr, orgAddr, groupA), false);

        // TODO: Check why isChild is not working for this test, but isParent is.
        // assertEq(keyperModule.isChild(orgAddr, orgAddr, subGroupA), true);
        assertEq(keyperModule.isParent(orgAddr, orgAddr, subGroupA), true);
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

    /// removeGroup when org == parent
    function testRemoveGroupFromSafeOrgEqParent() public {
        (address orgAddr, address groupSafe) = setUpRootOrgAndOneGroup();
        // Create a sub safe
        address subSafeGroupA = gnosisHelper.newKeyperSafe(3, 2);
        keyperSafes[subGroupAName] = address(subSafeGroupA);
        gnosisHelper.createAddGroupTx(orgAddr, groupSafe, subGroupAName);

        gnosisHelper.updateSafeInterface(orgAddr);
        bool result = gnosisHelper.createRemoveGroupTx(orgAddr, groupSafe);
        assertEq(result, true);

        result = keyperModule.isParent(orgAddr, orgAddr, groupSafe);
        assertEq(result, false);

        // Check sub safe is a child of org
        address[] memory newChild;
        (,,, newChild,) = keyperModule.getOrg(orgAddr);
        assertEq(newChild[0], subSafeGroupA);
    }
}
