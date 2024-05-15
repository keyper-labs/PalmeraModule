// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../../src/SigningUtils.sol";
import "./SkipGnosisSafeHelper.t.sol";
import "@solenv/Solenv.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {KeyperRoles} from "../../src/KeyperRoles.sol";
import {KeyperGuard} from "../../src/KeyperGuard.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

/// Script to setup the environment
contract SkipSetupEnv is Script, SkipGnosisSafeHelper {
    using SafeMath for uint256;

    KeyperModule keyperModule;
    KeyperGuard keyperGuard;
    KeyperRoles keyperRolesContract;

    address gnosisSafeAddr;
    address keyperRolesDeployed;
    address receiver = address(0xABC123);
    address zeroAddress = address(0x0);
    address sentinel = address(0x1);
    uint256 initOwners = 10;

    // Org, Squad and subSquad String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string squadA1Name = "SquadA1";
    string squadA2Name = "SquadA2";
    string squadBName = "SquadB";
    string subSquadA1Name = "subSquadA1";
    string subSquadB1Name = "subSquadB1";
    string subSubSquadA1Name = "SubSubSquadA";

    bytes32 orgHash;

    function run() public {
        Solenv.config();
        vm.startBroadcast();
        keyperRolesContract = KeyperRoles(vm.envAddress("KEYPER_ROLES_ADDRESS"));
        keyperModule = KeyperModule(vm.envAddress("KEYPER_MODULE_ADDRESS"));
        keyperGuard = KeyperGuard(vm.envAddress("KEYPER_GUARD_ADDRESS"));
        receiver = vm.envAddress("RECEIVER_ADDRESS");
        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisSafeAddr = setupSeveralSafeEnv(30);
        // setting keyperRoles Address
        setKeyperRoles(address(keyperRolesContract));
        // Update gnosisHelper
        setKeyperModule(address(keyperModule));
        // Update gnosisHelper
        setKeyperGuard(address(keyperGuard));
        // Enable keyper module
        enableModuleTx(gnosisSafeAddr);
        // Enable keyper Guard
        enableGuardTx(gnosisSafeAddr);
        console.log("Finalize Config Environment... ");
        vm.stopBroadcast();
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
        address rootAddr = newKeyperSafe(4, 2);
        console.log("Root address: ", rootAddr);
        bool result = registerOrgTx(orgNameArg);
        // Get org Id
        orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        rootId = keyperModule.getSquadIdBySafe(orgHash, rootAddr);

        address squadSafe = newKeyperSafe(4, 2);
        console.log("Squad A1 address: ", squadSafe);
        // Create squad through safe tx
        result = createAddSquadTx(rootId, squadA1NameArg);
        squadIdA1 = keyperModule.getSquadIdBySafe(orgHash, squadSafe);

        return (rootId, squadIdA1);
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
        returns (uint256 rootId, uint256 squadIdA1, uint256 subSquadIdA1)
    {
        // Create root & squadA1
        (rootId, squadIdA1) =
            setupRootOrgAndOneSquad(orgNameArg, squadA1NameArg);
        address safeSubSquadA1 = newKeyperSafe(2, 1);

        // Create subsquadA1
        bool result = createAddSquadTx(squadIdA1, subSquadA1NameArg);
        orgHash = keyperModule.getOrgBySquad(squadIdA1);
        // Get subsquadA1 Id
        subSquadIdA1 = keyperModule.getSquadIdBySafe(orgHash, safeSubSquadA1);
        return (rootId, squadIdA1, subSquadIdA1);
    }
}
