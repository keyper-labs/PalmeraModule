// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/SigningUtils.sol";
import "./GnosisSafeHelper.t.sol";
import "./KeyperModuleHelper.t.sol";
import {KeyperModule} from "../src/KeyperModule.sol";

contract TestKeyperSafe is Test, SigningUtils {
    KeyperModule keyperModule;
    GnosisSafeHelper gnosisHelper;
    KeyperModuleHelper keyperHelper;

    address gnosisSafeAddr;
    address keyperModuleAddr;
    // Helper mapping to keep track safes associated with a role
    mapping(string => address) keyperSafes;

    function setUp() public {
        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisHelper = new GnosisSafeHelper();
        gnosisSafeAddr = gnosisHelper.setupSafe();
        // console.log("Main safe addres", gnosisSafeAddr);

        // Init KeyperModule
        keyperModule = new KeyperModule();
        keyperModuleAddr = address(keyperModule);
        // Init keyperModuleHelper
        keyperHelper = new KeyperModuleHelper();
        keyperHelper.initHelper(keyperModule, 10);
        // Enable keyper module
        gnosisHelper.enableModuleTx(gnosisSafeAddr, address(keyperModule));
    }

    function testCreateOrgFromSafe() public {
        // Create createOrg calldata
        bool result = gnosisHelper.createOrgTx("Main Org", keyperModuleAddr);
        assertEq(result, true);
        (
            string memory name,
            address admin,
            address safe,
            address parent
        ) = keyperModule.getOrg(gnosisSafeAddr);
        assertEq(name, "Main Org");
        assertEq(admin, gnosisSafeAddr);
        assertEq(safe, gnosisSafeAddr);
        assertEq(parent, address(0));
    }

    function testCreateGroupFromSafe() public {
        // First safe as org
        string memory orgName = "Main Org";
        bool result = gnosisHelper.createOrgTx(orgName, keyperModuleAddr);
        assertEq(result, true);
        keyperSafes[orgName] = address(gnosisHelper.gnosisSafe());
        vm.label(keyperSafes[orgName], orgName);

        // Create new safe with setup called while creating contract
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        console.log("New group safe", groupSafe);
        address[] memory owners = gnosisHelper.gnosisSafe().getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisHelper.gnosisSafe().getThreshold(), 2);
        // Enable keyper module
        result = gnosisHelper.enableModuleTx(groupSafe, keyperModuleAddr);
        assertEq(result, true);

        // Create SubGroup calldata
        string memory groupName = "GroupA";
        keyperSafes[groupName] = address(groupSafe);
        vm.label(keyperSafes[groupName], groupName);
        // Update gnosisSafe interface pointer from Org
        address orgAddr = keyperSafes[orgName];
        gnosisHelper.updateSafeInterface(orgAddr);
        result = gnosisHelper.createAddGroupTx(
            orgAddr,
            groupSafe,
            orgAddr,
            orgAddr,
            groupName,
            keyperModuleAddr
        );
        assertEq(result, true);

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
}
