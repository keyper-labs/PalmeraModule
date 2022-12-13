// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {console} from "forge-std/console.sol";

contract KeyperSafeBuilder is Test {
    GnosisSafeHelper public gnosisHelper;
    KeyperModule public keyperModule;

    mapping(string => address) public keyperSafes;

    function setUpParams(
        KeyperModule keyperModuleArg,
        GnosisSafeHelper gnosisHelperArg
    ) public {
        keyperModule = keyperModuleArg;
        gnosisHelper = gnosisHelperArg;
    }

    // Just deploy a root org and a Group
    //           RootOrg
    //              |
    //           groupA1
    function setupRootOrgAndOneGroup(
        string memory orgNameArg,
        string memory groupA1NameArg
    ) public returns (uint256 rootId, uint256 groupIdA1, uint256 rootSafeId) {
        // Register Org through safe tx
        address rootAddr = gnosisHelper.newKeyperSafe(4, 2);
        bool result = gnosisHelper.registerOrgTx(orgNameArg);
        // address rootAddr = address(gnosisHelper.gnosisSafe());
        address groupSafe = gnosisHelper.newKeyperSafe(4, 2);
        // Get org Id
        bytes32 orgId = keyperModule.getOrgBySafe(rootAddr);
        rootId = keyperModule.getGroupIdBySafe(orgId, rootAddr);
        // Create group through safe tx
        result = gnosisHelper.createAddGroupTx(rootId, groupA1NameArg);
        groupIdA1 = keyperModule.getGroupIdBySafe(orgId, groupSafe);

        // Create Another Safe like Root Safe
        address rootSafe = gnosisHelper.newKeyperSafe(3, 2);
        // update safe of gonsis helper
        gnosisHelper.updateSafeInterface(rootAddr);
        // Create Root Safe Group
        string memory rootSafeName = "AnoterRootSafe";
        result = gnosisHelper.createRootSafeTx(rootSafe, rootSafeName);
        rootSafeId = keyperModule.getGroupIdBySafe(orgId, rootSafe);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(groupSafe, 100 gwei);

        return (rootId, groupIdA1, rootSafeId);
    }

    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1
    //              |
    //        safeSubGroupA1
    function setupOrgThreeTiersTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory subGroupA1NameArg
    )
        public
        returns (uint256 rootId, uint256 groupIdA1, uint256 subGroupIdA1)
    {
        // Create root & groupA1
        (rootId, groupIdA1,) =
            setupRootOrgAndOneGroup(orgNameArg, groupA1NameArg);
        address safeSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        // Create subgroupA1
        gnosisHelper.createAddGroupTx(groupIdA1, subGroupA1NameArg);
        bytes32 orgId = keyperModule.getOrgByGroup(groupIdA1);
        // Get subgroupA1 Id
        subGroupIdA1 = keyperModule.getGroupIdBySafe(orgId, safeSubGroupA1);
        return (rootId, groupIdA1, subGroupIdA1);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeGroupA1
    //              |
    //        safeSubGroupA1
    //              |
    //      safeSubSubGroupA1
    function setupOrgFourTiersTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory subGroupA1NameArg,
        string memory subSubGroupA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 subGroupIdA1,
            uint256 subSubGroupIdA1
        )
    {
        (rootId, groupIdA1, subGroupIdA1) = setupOrgThreeTiersTree(
            orgNameArg, groupA1NameArg, subGroupA1NameArg
        );

        address safeSubSubGroupA1 = gnosisHelper.newKeyperSafe(2, 1);
        gnosisHelper.createAddGroupTx(subGroupIdA1, subSubGroupA1NameArg);
        bytes32 orgId = keyperModule.getOrgByGroup(groupIdA1);
        // Get subgroupA1 Id
        subSubGroupIdA1 =
            keyperModule.getGroupIdBySafe(orgId, safeSubSubGroupA1);

        return (rootId, groupIdA1, subGroupIdA1, subSubGroupIdA1);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      groupA1   GroupB
    //        |
    //  subGroupA1
    //      |
    //  SubSubGroupA1
    function setUpBaseOrgTree(
        string memory orgNameArg,
        string memory groupA1NameArg,
        string memory groupBNameArg,
        string memory subGroupA1NameArg,
        string memory subSubGroupA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 groupIdA1,
            uint256 groupIdB,
            uint256 subGroupIdA1,
            uint256 subSubGroupIdA1
        )
    {
        (rootId, groupIdA1, subGroupIdA1, subSubGroupIdA1) =
        setupOrgFourTiersTree(
            orgNameArg, groupA1NameArg, subGroupA1NameArg, subSubGroupA1NameArg
        );

        address safeGroupB = gnosisHelper.newKeyperSafe(2, 1);
        gnosisHelper.createAddGroupTx(rootId, groupBNameArg);
        bytes32 orgId = keyperModule.getOrgByGroup(groupIdA1);
        // Get groupIdB Id
        groupIdB = keyperModule.getGroupIdBySafe(orgId, safeGroupB);

        return (rootId, groupIdA1, groupIdB, subGroupIdA1, subSubGroupIdA1);
    }
}
