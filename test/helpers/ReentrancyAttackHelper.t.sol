// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "./SafeHelper.t.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/libraries/Enum.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/// @notice Helper contract handling ReentrancyAttack
/// @custom:security-contact general@palmeradao.xyz
contract AttackerHelper is Test, SignDigestHelper, SignersHelper {
    PalmeraModule public palmera;
    SafeHelper public safeHelper;
    Attacker public attacker;

    mapping(string => address) public palmeraSafes;

    /// function to initialize the helper
    /// @param palmeraArg instance of PalmeraModule
    /// @param attackerArg instance of Attacker
    /// @param safeHelperArg instance of SafeHelper
    /// @param numberOwners number of owners to initialize
    function initHelper(
        PalmeraModule palmeraArg,
        Attacker attackerArg,
        SafeHelper safeHelperArg,
        uint256 numberOwners
    ) public {
        palmera = palmeraArg;
        attacker = attackerArg;
        safeHelper = safeHelperArg;
        initOnwers(numberOwners);
    }

    /// function to encode signatures for Attack PalmeraTx
    /// @param org Organisation address
    /// @param superSafe Super Safe address
    /// @param targetSafe Target Safe address
    /// @param to Address to send the transaction
    /// @param value Value to send
    /// @param data Data payload
    /// @param operation Operation type
    /// @return signatures Packed signatures data (v, r, s)
    function encodeSignaturesForAttackPalmeraTx(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        uint256 nonce = palmera.nonce();
        bytes32 txHashed = palmera.getTransactionHash(
            org, superSafe, targetSafe, to, value, data, operation, nonce
        );

        uint256 threshold = attacker.getThreshold();
        address[] memory owners = attacker.getOwners();
        address[] memory sortedOwners = sortAddresses(owners);

        uint256[] memory ownersPKFromAttacker = new uint256[](threshold);
        for (uint256 i; i < threshold; ++i) {
            ownersPKFromAttacker[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(ownersPKFromAttacker, txHashed);

        return signatures;
    }

    /// function to set Attacker Tree for the organisation
    /// @param _orgName Name of the organisation
    /// @return orgHash, orgAddr, attackerSafe, victim
    function setAttackerTree(string memory _orgName)
        public
        returns (bytes32, address, address, address)
    {
        safeHelper.registerOrgTx(_orgName);
        palmeraSafes[_orgName] = address(safeHelper.safeWallet());
        address orgAddr = palmeraSafes[_orgName];

        safeHelper.updateSafeInterface(address(attacker));
        string memory nameAttacker = "Attacker";
        palmeraSafes[nameAttacker] = address(attacker);

        address attackerSafe = palmeraSafes[nameAttacker];
        bytes32 orgHash = keccak256(abi.encodePacked(_orgName));
        uint256 rootOrgId = palmera.getSafeIdBySafe(orgHash, orgAddr);

        vm.startPrank(attackerSafe);
        palmera.addSafe(rootOrgId, nameAttacker);
        vm.stopPrank();

        address victim = safeHelper.newPalmeraSafe(2, 1);
        string memory nameVictim = "Victim";
        palmeraSafes[nameVictim] = address(victim);
        uint256 attackerSafeId = palmera.getSafeIdBySafe(orgHash, attackerSafe);

        vm.startPrank(victim);
        palmera.addSafe(attackerSafeId, nameVictim);
        vm.stopPrank();
        uint256 victimSafeId = palmera.getSafeIdBySafe(orgHash, victim);

        vm.deal(victim, 100 gwei);

        vm.startPrank(orgAddr);
        palmera.setRole(
            DataTypes.Role.SAFE_LEAD, address(attackerSafe), victimSafeId, true
        );
        vm.stopPrank();

        return (orgHash, orgAddr, attackerSafe, victim);
    }
}
