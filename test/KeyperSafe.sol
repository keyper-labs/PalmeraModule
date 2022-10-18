// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import {KeyperModule, IGnosisSafe} from "../src/KeyperModule.sol";
// import {MockAuthority} from "@solmate/test/utils/mocks/MockAuthority.sol";
import {KeyperRoles} from "../src/KeyperRoles.sol";

contract TestKeyperSafe is Test, SigningUtils, Constants {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;
    KeyperRoles keyperRoles;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    // address public testAddress = address(0xBEFF);
    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;
    string orgName = "Main Org";
    string groupAName = "GroupA";
    string groupBName = "GroupB";
    string subGroupAName = "SubGroupA";
    // MockAuthority mockKeyperRoles;

    function setUp() public {
        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafeEnv();

        // Init KeyperModule
        address masterCopy = gnosisHelper.gnosisMasterCopy();
        address safeFactory = address(gnosisHelper.safeFactory());
        // TODO: rolesAuthority setup, Mock calls to auth
        // mockKeyperRoles = new MockAuthority(true);
        keyperRoles = new KeyperRoles();
        keyperModule = new KeyperModule(
            masterCopy,
            safeFactory,
            address(mockKeyperRoles)
        );
        keyperModuleAddr = address(keyperModule);
        // Init keyperModuleHelper
        keyperHelper = new KeyperModuleHelper();
        keyperHelper.initHelper(keyperModule, 30);
        // Update gnosisHelper
        gnosisHelper.setKeyperModule(address(keyperModule));
        // Enable keyper module
        gnosisHelper.enableModuleTx(gnosisSafeAddr);
    }

    function testCreateSafeFromModule() public {
        address newSafe = keyperHelper.createSafeProxy(4, 2);
        assertFalse(newSafe == address(0));
        // Verify newSafe has keyper modulle enabled
        GnosisSafe safe = GnosisSafe(payable(newSafe));
        bool isKeyperModuleEnabled = safe.isModuleEnabled(
            address(keyperHelper.keyper())
        );
        assertEq(isKeyperModuleEnabled, true);
    }

    function testRegisterOrgFromSafe() public {
        // Create registerOrg calldata
        bool result = gnosisHelper.registerOrgTx(
            orgName,
            address(mockKeyperRoles)
        );
        assertEq(result, true);
        (
            string memory name,
            address admin,
            address safe,
            address parent
        ) = keyperModule.getOrg(gnosisSafeAddr);
        assertEq(name, orgName);
        assertEq(admin, gnosisSafeAddr);
        assertEq(safe, gnosisSafeAddr);
        assertEq(parent, address(0));
    }

    function testCreateGroupFromSafe() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(
            orgName,
            address(mockKeyperRoles)
        );
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

    function testAdminExecOnBehalf() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(
            orgName, 
            address(mockKeyperRoles)
        );
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
            orgAddr,
            groupSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
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
        console.log("receiver balance: ", receiver.balance);
        assertEq(receiver.balance, 2 gwei);
    }

    function testRevertInvalidSignatureExecOnBehalf() public {
        // Set initialsafe as org
        bool result = gnosisHelper.registerOrgTx(
            orgName, 
            address(mockKeyperRoles)
        );
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
            orgAddr,
            groupSafe,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
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
        bool result = gnosisHelper.registerOrgTx(
            orgName,
            address(mockKeyperRoles)
        );
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
        result = gnosisHelper.createAddGroupTx(
            orgAddr,
            safeGroupA,
            nameSubGroupA
        );
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
            groupA,
            subGroupA,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
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
            subGroupA,
            groupA,
            receiver,
            2 gwei,
            emptyData,
            Enum.Operation(0)
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
}
