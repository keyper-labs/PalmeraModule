// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./SafeHelper.t.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";

/// @notice Helper contract handling and create Org and Squad with different levels
/// @custom:security-contact general@palmeradao.xyz
contract KeyperSafeBuilder is Test {
    SafeHelper public safeHelper;
    PalmeraModule public keyperModule;

    // fixed array of 4 owners
    uint256[] ownersRootPK = new uint256[](4);
    uint256[] ownersSuperPK = new uint256[](4);

    mapping(string => address) public keyperSafes;

    function setUpParams(
        PalmeraModule keyperModuleArg,
        SafeHelper safeHelperArg
    ) public {
        keyperModule = keyperModuleArg;
        safeHelper = safeHelperArg;
    }

    // Just deploy a root org and a Squad
    //           RootOrg
    //              |
    //           squadA1
    function setupRootOrgAndOneSquad(
        string memory orgNameArg,
        string memory squadA1NameArg
    ) public returns (uint256 rootId, uint256 squadIdA1) {
        // Register Org through safe tx
        address rootAddr;
        (rootAddr, ownersRootPK) = safeHelper.newKeyperSafeWithPKOwners(4, 2);
        bool result = safeHelper.registerOrgTx(orgNameArg);
        // Get org Id
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        rootId = keyperModule.getSquadIdBySafe(orgHash, rootAddr);

        address squadSafeAddr;
        (squadSafeAddr, ownersSuperPK) =
            safeHelper.newKeyperSafeWithPKOwners(4, 2);

        // Create squad through safe tx
        result = safeHelper.createAddSquadTx(rootId, squadA1NameArg);
        squadIdA1 = keyperModule.getSquadIdBySafe(orgHash, squadSafeAddr);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(squadSafeAddr, 100 gwei);

        return (rootId, squadIdA1);
    }

    // Deploy 1 org with 2 squad at same level
    //           RootA
    //         |         |
    //     squadA1    squadA2
    function setupRootWithTwoSquads(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory squadA2NameArg
    ) public returns (uint256 rootIdA, uint256 squadIdA1, uint256 squadIdA2) {
        (rootIdA, squadIdA1) =
            setupRootOrgAndOneSquad(orgNameArg, squadA1NameArg);
        (,,, address rootAddr,,) = keyperModule.getSquadInfo(rootIdA);

        // Create squadA2
        address squadA2 = safeHelper.newKeyperSafe(4, 2);

        // Create squad through safe tx
        safeHelper.createAddSquadTx(rootIdA, squadA2NameArg);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        squadIdA2 = keyperModule.getSquadIdBySafe(orgHash, squadA2);
        vm.deal(squadA2, 100 gwei);

        return (rootIdA, squadIdA1, squadIdA2);
    }

    // Deploy 1 org with 2 root safe with 1 squad each
    //           RootA      RootB
    //              |         |
    //           squadA1    squadB1
    function setupTwoRootOrgWithOneSquadEach(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory rootBNameArg,
        string memory squadB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            uint256 squadIdB1
        )
    {
        (rootIdA, squadIdA1) =
            setupRootOrgAndOneSquad(orgNameArg, squadA1NameArg);
        (,,, address rootAddr,,) = keyperModule.getSquadInfo(rootIdA);

        // Create Another Safe like Root Safe
        address rootBAddr = safeHelper.newKeyperSafe(3, 2);
        // update safe of gonsis helper
        safeHelper.updateSafeInterface(rootAddr);
        // Create Root Safe Squad
        bool result = safeHelper.createRootSafeTx(rootBAddr, rootBNameArg);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        rootIdB = keyperModule.getSquadIdBySafe(orgHash, rootBAddr);
        vm.deal(rootBAddr, 100 gwei);

        // Create squadB for rootB
        address squadSafeB = safeHelper.newKeyperSafe(4, 2);

        // Create squad through safe tx
        result = safeHelper.createAddSquadTx(rootIdB, squadB1NameArg);
        squadIdB1 = keyperModule.getSquadIdBySafe(orgHash, squadSafeB);
        vm.deal(squadSafeB, 100 gwei);

        return (rootIdA, squadIdA1, rootIdB, squadIdB1);
    }

    // Deploy 1 org with 2 root safe with 1 squad each
    //           RootA         RootB
    //              |            |
    //           squadA1      squadB1
    //              |            |
    //        childSquadA1  childSquadA1
    function setupTwoRootOrgWithOneSquadAndOneChildEach(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory rootBNameArg,
        string memory squadB1NameArg,
        string memory childSquadA1NameArg,
        string memory childSquadB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            uint256 squadIdB1,
            uint256 childSquadIdA1,
            uint256 childSquadIdB1
        )
    {
        (rootIdA, squadIdA1, rootIdB, squadIdB1) =
        setupTwoRootOrgWithOneSquadEach(
            orgNameArg, squadA1NameArg, rootBNameArg, squadB1NameArg
        );
        (,,, address rootAddr,,) = keyperModule.getSquadInfo(rootIdA);
        bytes32 orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        // Create childSquadA1
        address childSquadA1 = safeHelper.newKeyperSafe(4, 2);
        safeHelper.createAddSquadTx(squadIdA1, childSquadA1NameArg);
        childSquadIdA1 = keyperModule.getSquadIdBySafe(orgHash, childSquadA1);
        vm.deal(childSquadA1, 100 gwei);

        // Create childSquadB1
        address childSquadB1 = safeHelper.newKeyperSafe(4, 2);
        safeHelper.createAddSquadTx(squadIdB1, childSquadB1NameArg);
        childSquadIdB1 = keyperModule.getSquadIdBySafe(orgHash, childSquadB1);
        vm.deal(childSquadB1, 100 gwei);

        return (
            rootIdA,
            squadIdA1,
            rootIdB,
            squadIdB1,
            childSquadIdA1,
            childSquadIdB1
        );
    }

    // Deploy 2 org with 2 root safe with 1 squad each
    //           RootA         RootB
    //              |            |
    //           squadA1      squadB1
    //              |            |
    //        childSquadA1  childSquadA1
    function setupTwoOrgWithOneRootOneSquadAndOneChildEach(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory rootBNameArg,
        string memory squadB1NameArg,
        string memory childSquadA1NameArg,
        string memory childSquadB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 squadIdA1,
            uint256 rootIdB,
            uint256 squadIdB1,
            uint256 childSquadIdA1,
            uint256 childSquadIdB1
        )
    {
        (rootIdA, squadIdA1) =
            setupRootOrgAndOneSquad(orgNameArg, squadA1NameArg);
        (rootIdB, squadIdB1) =
            setupRootOrgAndOneSquad(rootBNameArg, squadB1NameArg);
        bytes32 orgHash1 = keyperModule.getOrgBySquad(rootIdA);
        bytes32 orgHash2 = keyperModule.getOrgBySquad(rootIdB);

        // Create childSquadA1
        address childSquadA1 = safeHelper.newKeyperSafe(4, 2);
        safeHelper.createAddSquadTx(squadIdA1, childSquadA1NameArg);
        childSquadIdA1 = keyperModule.getSquadIdBySafe(orgHash1, childSquadA1);
        vm.deal(childSquadA1, 100 gwei);

        // Create childSquadB1
        address childSquadB1 = safeHelper.newKeyperSafe(4, 2);
        safeHelper.createAddSquadTx(squadIdB1, childSquadB1NameArg);
        childSquadIdB1 = keyperModule.getSquadIdBySafe(orgHash2, childSquadB1);
        vm.deal(childSquadB1, 100 gwei);

        return (
            rootIdA,
            squadIdA1,
            rootIdB,
            squadIdB1,
            childSquadIdA1,
            childSquadIdB1
        );
    }

    // Deploy 3 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeSquadA1
    //              |
    //        safeSubSquadA1
    function setupOrgThreeTiersTree(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory subSquadA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256[] memory,
            uint256[] memory
        )
    {
        // Create root & squadA1
        (rootId, squadIdA1) =
            setupRootOrgAndOneSquad(orgNameArg, squadA1NameArg);
        address safeSubSquadA1 = safeHelper.newKeyperSafe(2, 1);

        // Create subsquadA1
        safeHelper.createAddSquadTx(squadIdA1, subSquadA1NameArg);
        bytes32 orgHash = keyperModule.getOrgBySquad(squadIdA1);
        // Get subsquadA1 Id
        subSquadIdA1 = keyperModule.getSquadIdBySafe(orgHash, safeSubSquadA1);
        return (rootId, squadIdA1, subSquadIdA1, ownersRootPK, ownersSuperPK);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //              |
    //         safeSquadA1
    //              |
    //        safeSubSquadA1
    //              |
    //      safeSubSubSquadA1
    function setupOrgFourTiersTree(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory subSquadA1NameArg,
        string memory subSubSquadA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 subSquadIdA1,
            uint256 subSubSquadIdA1
        )
    {
        (rootId, squadIdA1, subSquadIdA1,,) = setupOrgThreeTiersTree(
            orgNameArg, squadA1NameArg, subSquadA1NameArg
        );

        address safeSubSubSquadA1 = safeHelper.newKeyperSafe(2, 1);

        safeHelper.createAddSquadTx(subSquadIdA1, subSubSquadA1NameArg);
        bytes32 orgHash = keyperModule.getOrgBySquad(squadIdA1);
        // Get subsquadA1 Id
        subSubSquadIdA1 =
            keyperModule.getSquadIdBySafe(orgHash, safeSubSubSquadA1);

        return (rootId, squadIdA1, subSquadIdA1, subSubSquadIdA1);
    }

    // Deploy 4 keyperSafes : following structure
    //           RootOrg
    //          |      |
    //      squadA1   SquadB
    //        |
    //  subSquadA1
    //      |
    //  SubSubSquadA1
    function setUpBaseOrgTree(
        string memory orgNameArg,
        string memory squadA1NameArg,
        string memory squadBNameArg,
        string memory subSquadA1NameArg,
        string memory subSubSquadA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 squadIdA1,
            uint256 squadIdB,
            uint256 subSquadIdA1,
            uint256 subSubSquadIdA1
        )
    {
        (rootId, squadIdA1, subSquadIdA1, subSubSquadIdA1) =
        setupOrgFourTiersTree(
            orgNameArg, squadA1NameArg, subSquadA1NameArg, subSubSquadA1NameArg
        );

        address safeSquadB = safeHelper.newKeyperSafe(2, 1);
        safeHelper.createAddSquadTx(rootId, squadBNameArg);
        bytes32 orgHash = keyperModule.getOrgBySquad(squadIdA1);
        // Get squadIdB Id
        squadIdB = keyperModule.getSquadIdBySafe(orgHash, safeSquadB);

        return (rootId, squadIdA1, squadIdB, subSquadIdA1, subSubSquadIdA1);
    }
}
