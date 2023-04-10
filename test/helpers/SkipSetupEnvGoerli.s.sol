// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../../src/SigningUtils.sol";
import "./SkipGnosisSafeHelperGoerli.t.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";
import {PalmeraRoles} from "../../src/PalmeraRoles.sol";
import {PalmeraGuard} from "../../src/PalmeraGuard.sol";
import {SafeMath} from "@openzeppelin/utils/math/SafeMath.sol";

contract SkipSetupEnvGoerli is Script, SkipGnosisSafeHelperGoerli {
    using SafeMath for uint256;

    PalmeraModule keyperModule;
    PalmeraGuard keyperGuard;
    PalmeraRoles keyperRolesContract;

    address gnosisSafeAddr;
    address keyperRolesDeployed;
    address receiver;
    address zeroAddress = address(0x0);
    address sentinel = address(0x1);

    // Org, Squad and subSquad String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string squadA1Name = "SquadA1";
    string squadA2Name = "SquadA2";
    string squadBName = "SquadB";
    string subSquadA1Name = "subSquadA1";

    bytes32 orgHash;

    function run() public {
        vm.startBroadcast();
        keyperRolesContract =
            PalmeraRoles(vm.envAddress("PALMERA_ROLES_ADDRESS"));
        keyperModule = PalmeraModule(vm.envAddress("PALMERA_MODULE_ADDRESS"));
        keyperGuard = PalmeraGuard(vm.envAddress("PALMERA_GUARD_ADDRESS"));
        receiver = vm.envAddress("RECEIVER_ADDRESS");
        // Init a new safe as main organization (3 owners, 1 threshold)
        gnosisSafeAddr = setupSeveralSafeEnv(30);
        // setting keyperRoles Address
        setPalmeraRoles(address(keyperRolesContract));
        // Update gnosisHelper
        setPalmeraModule(address(keyperModule));
        // Update gnosisHelper
        setPalmeraGuard(address(keyperGuard));
        // Enable keyper module
        enableModuleTx(gnosisSafeAddr);
        // Enable keyper Guard
        enableGuardTx(gnosisSafeAddr);
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
        orgHash = keyperModule.getOrgHashBySafe(rootAddr);
        rootId = keyperModule.getSquadIdBySafe(orgHash, rootAddr);

        address squadSafe = newPalmeraSafe(4, 2);
        console.log("Squad A1 address: ", squadSafe);
        // Create squad through safe tx
        result = createAddSquadTx(rootId, squadA1NameArg);
        squadIdA1 = keyperModule.getSquadIdBySafe(orgHash, squadSafe);

        return (rootId, squadIdA1);
    }
}
