// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "./SafeHelper.t.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";

/// @notice Helper contract handling and create Org and Safe with different levels
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraSafeBuilder is Test {
    SafeHelper public safeHelper;
    PalmeraModule public palmeraModule;

    // fixed array of 4 owners
    uint256[] ownersRootPK = new uint256[](4);
    uint256[] ownersSuperPK = new uint256[](4);

    mapping(string => address) public palmeraSafes;

    function setUpParams(
        PalmeraModule palmeraModuleArg,
        SafeHelper safeHelperArg
    ) public {
        palmeraModule = palmeraModuleArg;
        safeHelper = safeHelperArg;
    }

    // Just deploy a root org and a Safe
    //           RootOrg
    //              |
    //           safeA1
    function setupRootOrgAndOneSafe(
        string memory orgNameArg,
        string memory safeA1NameArg
    ) public returns (uint256 rootId, uint256 safeIdA1) {
        // Register Org through safe tx
        address rootAddr;
        (rootAddr, ownersRootPK) = safeHelper.newPalmeraSafeWithPKOwners(4, 2);
        bool result = safeHelper.registerOrgTx(orgNameArg);
        // Get org Id
        bytes32 orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        rootId = palmeraModule.getSafeIdBySafe(orgHash, rootAddr);

        address safeAddr;
        (safeAddr, ownersSuperPK) = safeHelper.newPalmeraSafeWithPKOwners(4, 2);

        // Create safe through safe tx
        result = safeHelper.createAddSafeTx(rootId, safeA1NameArg);
        safeIdA1 = palmeraModule.getSafeIdBySafe(orgHash, safeAddr);

        vm.deal(rootAddr, 100 gwei);
        vm.deal(safeAddr, 100 gwei);

        return (rootId, safeIdA1);
    }

    // Deploy 1 org with 2 safe at same level
    //           RootA
    //         |         |
    //     safeA1    safeA2
    function setupRootWithTwoSafes(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory safeA2NameArg
    ) public returns (uint256 rootIdA, uint256 safeIdA1, uint256 safeIdA2) {
        (rootIdA, safeIdA1) = setupRootOrgAndOneSafe(orgNameArg, safeA1NameArg);
        (,,, address rootAddr,,) = palmeraModule.getSafeInfo(rootIdA);

        // Create safeA2
        address safeA2 = safeHelper.newPalmeraSafe(4, 2);

        // Create safe through safe tx
        safeHelper.createAddSafeTx(rootIdA, safeA2NameArg);
        bytes32 orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        safeIdA2 = palmeraModule.getSafeIdBySafe(orgHash, safeA2);
        vm.deal(safeA2, 100 gwei);

        return (rootIdA, safeIdA1, safeIdA2);
    }

    // Deploy 1 org with 2 root safe with 1 safe each
    //           RootA      RootB
    //              |         |
    //           safeA1    safeB1
    function setupTwoRootOrgWithOneSafeEach(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory rootBNameArg,
        string memory safeB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 safeIdA1,
            uint256 rootIdB,
            uint256 safeIdB1
        )
    {
        (rootIdA, safeIdA1) = setupRootOrgAndOneSafe(orgNameArg, safeA1NameArg);
        (,,, address rootAddr,,) = palmeraModule.getSafeInfo(rootIdA);

        // Create Another Safe like Root Safe
        address rootBAddr = safeHelper.newPalmeraSafe(3, 2);
        // update safe of gonsis helper
        safeHelper.updateSafeInterface(rootAddr);
        // Create Root Safe
        bool result = safeHelper.createRootSafeTx(rootBAddr, rootBNameArg);
        bytes32 orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        rootIdB = palmeraModule.getSafeIdBySafe(orgHash, rootBAddr);
        vm.deal(rootBAddr, 100 gwei);

        // Create safeB for rootB
        address safeB = safeHelper.newPalmeraSafe(4, 2);

        // Create safe through safe tx
        result = safeHelper.createAddSafeTx(rootIdB, safeB1NameArg);
        safeIdB1 = palmeraModule.getSafeIdBySafe(orgHash, safeB);
        vm.deal(safeB, 100 gwei);

        return (rootIdA, safeIdA1, rootIdB, safeIdB1);
    }

    // Deploy 1 org with 2 root safe with 1 safe each
    //           RootA         RootB
    //              |            |
    //           safeA1      safeB1
    //              |            |
    //        childSafeA1  childSafeA1
    function setupTwoRootOrgWithOneSafeAndOneChildEach(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory rootBNameArg,
        string memory safeB1NameArg,
        string memory childSafeA1NameArg,
        string memory childSafeB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 safeIdA1,
            uint256 rootIdB,
            uint256 safeIdB1,
            uint256 childSafeIdA1,
            uint256 childSafeIdB1
        )
    {
        (rootIdA, safeIdA1, rootIdB, safeIdB1) = setupTwoRootOrgWithOneSafeEach(
            orgNameArg, safeA1NameArg, rootBNameArg, safeB1NameArg
        );
        (,,, address rootAddr,,) = palmeraModule.getSafeInfo(rootIdA);
        bytes32 orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        // Create childSafeA1
        address childSafeA1 = safeHelper.newPalmeraSafe(4, 2);
        safeHelper.createAddSafeTx(safeIdA1, childSafeA1NameArg);
        childSafeIdA1 = palmeraModule.getSafeIdBySafe(orgHash, childSafeA1);
        vm.deal(childSafeA1, 100 gwei);

        // Create childSafeB1
        address childSafeB1 = safeHelper.newPalmeraSafe(4, 2);
        safeHelper.createAddSafeTx(safeIdB1, childSafeB1NameArg);
        childSafeIdB1 = palmeraModule.getSafeIdBySafe(orgHash, childSafeB1);
        vm.deal(childSafeB1, 100 gwei);

        return
            (rootIdA, safeIdA1, rootIdB, safeIdB1, childSafeIdA1, childSafeIdB1);
    }

    // Deploy 2 org with 2 root safe with 1 safe each
    //           RootA         RootB
    //              |            |
    //           safeA1      safeB1
    //              |            |
    //        childSafeA1  childSafeA1
    function setupTwoOrgWithOneRootOneSafeAndOneChildEach(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory rootBNameArg,
        string memory safeB1NameArg,
        string memory childSafeA1NameArg,
        string memory childSafeB1NameArg
    )
        public
        returns (
            uint256 rootIdA,
            uint256 safeIdA1,
            uint256 rootIdB,
            uint256 safeIdB1,
            uint256 childSafeIdA1,
            uint256 childSafeIdB1
        )
    {
        (rootIdA, safeIdA1) = setupRootOrgAndOneSafe(orgNameArg, safeA1NameArg);
        (rootIdB, safeIdB1) =
            setupRootOrgAndOneSafe(rootBNameArg, safeB1NameArg);
        bytes32 orgHash1 = palmeraModule.getOrgBySafe(rootIdA);
        bytes32 orgHash2 = palmeraModule.getOrgBySafe(rootIdB);

        // Create childSafeA1
        address childSafeA1 = safeHelper.newPalmeraSafe(4, 2);
        safeHelper.createAddSafeTx(safeIdA1, childSafeA1NameArg);
        childSafeIdA1 = palmeraModule.getSafeIdBySafe(orgHash1, childSafeA1);
        vm.deal(childSafeA1, 100 gwei);

        // Create childSafeB1
        address childSafeB1 = safeHelper.newPalmeraSafe(4, 2);
        safeHelper.createAddSafeTx(safeIdB1, childSafeB1NameArg);
        childSafeIdB1 = palmeraModule.getSafeIdBySafe(orgHash2, childSafeB1);
        vm.deal(childSafeB1, 100 gwei);

        return
            (rootIdA, safeIdA1, rootIdB, safeIdB1, childSafeIdA1, childSafeIdB1);
    }

    // Deploy 3 palmeraSafes : following structure
    //           RootOrg
    //              |
    //         safeA1
    //              |
    //        safeSubSafeA1
    function setupOrgThreeTiersTree(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory subSafeA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeIdA1,
            uint256[] memory,
            uint256[] memory
        )
    {
        // Create root & safeA1
        (rootId, safeIdA1) = setupRootOrgAndOneSafe(orgNameArg, safeA1NameArg);
        address safeSubSafeA1 = safeHelper.newPalmeraSafe(2, 1);

        // Create subsafeA1
        safeHelper.createAddSafeTx(safeIdA1, subSafeA1NameArg);
        bytes32 orgHash = palmeraModule.getOrgBySafe(safeIdA1);
        // Get subsafeA1 Id
        subSafeIdA1 = palmeraModule.getSafeIdBySafe(orgHash, safeSubSafeA1);
        return (rootId, safeIdA1, subSafeIdA1, ownersRootPK, ownersSuperPK);
    }

    // Deploy 4 palmeraSafes : following structure
    //           RootOrg
    //              |
    //         safeA1
    //              |
    //        safeSubSafeA1
    //              |
    //      safeSubSubSafeA1
    function setupOrgFourTiersTree(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory subSafeA1NameArg,
        string memory subSubSafeA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 subSafeIdA1,
            uint256 subSubSafeIdA1
        )
    {
        (rootId, safeIdA1, subSafeIdA1,,) =
            setupOrgThreeTiersTree(orgNameArg, safeA1NameArg, subSafeA1NameArg);

        address safeSubSubSafeA1 = safeHelper.newPalmeraSafe(2, 1);

        safeHelper.createAddSafeTx(subSafeIdA1, subSubSafeA1NameArg);
        bytes32 orgHash = palmeraModule.getOrgBySafe(safeIdA1);
        // Get subsafeA1 Id
        subSubSafeIdA1 =
            palmeraModule.getSafeIdBySafe(orgHash, safeSubSubSafeA1);

        return (rootId, safeIdA1, subSafeIdA1, subSubSafeIdA1);
    }

    // Deploy 4 palmeraSafes : following structure
    //           RootOrg
    //          |      |
    //      safeA1   SafeB
    //        |
    //  subSafeA1
    //      |
    //  SubSubSafeA1
    function setUpBaseOrgTree(
        string memory orgNameArg,
        string memory safeA1NameArg,
        string memory safeBNameArg,
        string memory subSafeA1NameArg,
        string memory subSubSafeA1NameArg
    )
        public
        returns (
            uint256 rootId,
            uint256 safeIdA1,
            uint256 safeIdB,
            uint256 subSafeIdA1,
            uint256 subSubSafeIdA1
        )
    {
        (rootId, safeIdA1, subSafeIdA1, subSubSafeIdA1) = setupOrgFourTiersTree(
            orgNameArg, safeA1NameArg, subSafeA1NameArg, subSubSafeA1NameArg
        );

        address safeB = safeHelper.newPalmeraSafe(2, 1);
        safeHelper.createAddSafeTx(rootId, safeBNameArg);
        bytes32 orgHash = palmeraModule.getOrgBySafe(safeIdA1);
        // Get safeIdB Id
        safeIdB = palmeraModule.getSafeIdBySafe(orgHash, safeB);

        return (rootId, safeIdA1, safeIdB, subSafeIdA1, subSubSafeIdA1);
    }
}
