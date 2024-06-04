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

    // Org, Safe and subSafe String names
    string orgName = "Main Org";
    string org2Name = "Second Org";
    string root2Name = "Second Root";
    string safeA1Name = "SafeA1";
    string safeA2Name = "SafeA2";
    string safeBName = "SafeB";
    string subSafeA1Name = "subSafeA1";
    string subSafeB1Name = "subSafeB1";
    string subSubSafeA1Name = "SubSubSafeA";

    bytes32 orgHash;

    function run() public {
        Solenv.config();
        vm.startBroadcast();
        palmeraRolesContract =
            PalmeraRoles(vm.envAddress("PALMERA_ROLES_ADDRESS"));
        palmeraModule = PalmeraModule(vm.envAddress("PALMERA_MODULE_ADDRESS"));
        palmeraGuard = PalmeraGuard(vm.envAddress("PALMERA_GUARD_ADDRESS"));
        receiver = vm.envAddress("RECEIVER_ADDRESS");
        // Init a new safe as main organisation (3 owners, 1 threshold)
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

    // Just deploy a root org and a Safe
    //           RootOrg
    //              |
    //           safeA1
    function setupRootOrgAndOneSafe(
        string memory orgNameArg,
        string memory safeA1NameArg
    ) public returns (uint256 rootId, uint256 safeIdA1) {
        // Register Org through safe tx
        address rootAddr = newPalmeraSafe(4, 2);
        console.log("Root address: ", rootAddr);
        bool result = registerOrgTx(orgNameArg);
        // Get org Id
        orgHash = palmeraModule.getOrgHashBySafe(rootAddr);
        rootId = palmeraModule.getSafeIdBySafe(orgHash, rootAddr);

        address safe = newPalmeraSafe(4, 2);
        console.log("Safe A1 address: ", safe);
        // Create safe through safe tx
        result = createAddSafeTx(rootId, safeA1NameArg);
        safeIdA1 = palmeraModule.getSafeIdBySafe(orgHash, safe);

        return (rootId, safeIdA1);
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
    ) public returns (uint256 rootId, uint256 safeIdA1, uint256 subSafeIdA1) {
        // Create root & safeA1
        (rootId, safeIdA1) = setupRootOrgAndOneSafe(orgNameArg, safeA1NameArg);
        address safeSubSafeA1 = newPalmeraSafe(2, 1);

        // Create subsafeA1
        bool result = createAddSafeTx(safeIdA1, subSafeA1NameArg);
        orgHash = palmeraModule.getOrgBySafe(safeIdA1);
        // Get subsafeA1 Id
        subSafeIdA1 = palmeraModule.getSafeIdBySafe(orgHash, safeSubSafeA1);
        return (rootId, safeIdA1, subSafeIdA1);
    }
}
