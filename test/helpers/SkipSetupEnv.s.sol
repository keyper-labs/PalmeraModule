// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../../src/SigningUtils.sol";
import "./SkipSafeHelper.t.sol";
import "@solenv/Solenv.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";
import {PalmeraRoles} from "../../src/PalmeraRoles.sol";
import {PalmeraGuard} from "../../src/PalmeraGuard.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

/// @notice Script to setup the environment
/// @custom:security-contact general@palmeradao.xyz
contract SkipSetupEnv is Script, SkipSafeHelper {
    using SafeMath for uint256;

    PalmeraModule palmeraModule;
    PalmeraGuard palmeraGuard;
    PalmeraRoles palmeraRolesContract;

    address safeAddr;
    address palmeraRolesDeployed;
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
        palmeraRolesContract =
            PalmeraRoles(vm.envAddress("PALMERA_ROLES_ADDRESS"));
        palmeraModule = PalmeraModule(vm.envAddress("PALMERA_MODULE_ADDRESS"));
        palmeraGuard = PalmeraGuard(vm.envAddress("PALMERA_GUARD_ADDRESS"));
        receiver = vm.envAddress("RECEIVER_ADDRESS");
        // Init a new safe as main organization (3 owners, 1 threshold)
        safeAddr = setupSeveralSafeEnv(30);
        // setting palmeraRoles Address
        setPalmeraRoles(address(palmeraRolesContract));
        // Update safeHelper
        setPalmeraModule(address(palmeraModule));
        // Update safeHelper
        setPalmeraGuard(address(palmeraGuard));
        // Enable palmera module
        enableModuleTx(safeAddr);
        // Enable palmera Guard
        enableGuardTx(safeAddr);
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
        address rootAddr = newPalmeraSafe(4, 2);
        console.log("Root address: ", rootAddr);
        bool result = registerOrgTx(orgNameArg);
        // Get org Id
        orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        rootId = palmeraModule.getSquadIdBySafe(orgHash, rootAddr);

        address squadSafe = newPalmeraSafe(4, 2);
        console.log("Squad A1 address: ", squadSafe);
        // Create squad through safe tx
        result = createAddSquadTx(rootId, squadA1NameArg);
        squadIdA1 = palmeraModule.getSquadIdBySafe(orgHash, squadSafe);

        return (rootId, squadIdA1);
    }

    // Deploy 3 palmeraSafes : following structure
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
        address safeSubSquadA1 = newPalmeraSafe(2, 1);

        // Create subsquadA1
        bool result = createAddSquadTx(squadIdA1, subSquadA1NameArg);
        orgHash = palmeraModule.getOrgBySquad(squadIdA1);
        // Get subsquadA1 Id
        subSquadIdA1 = palmeraModule.getSquadIdBySafe(orgHash, safeSubSquadA1);
        return (rootId, squadIdA1, subSquadIdA1);
    }
}
