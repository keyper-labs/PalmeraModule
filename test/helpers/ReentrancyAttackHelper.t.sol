// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "./SafeHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/// @notice Helper contract handling ReentrancyAttack
/// @custom:security-contact general@palmeradao.xyz
contract AttackerHelper is Test, SignDigestHelper, SignersHelper {
    KeyperModule public keyper;
    SafeHelper public safeHelper;
    Attacker public attacker;

    mapping(string => address) public keyperSafes;

    /// function to initialize the helper
    /// @param keyperArg instance of KeyperModule
    /// @param attackerArg instance of Attacker
    /// @param safeHelperArg instance of SafeHelper
    /// @param numberOwners number of owners to initialize
    function initHelper(
        KeyperModule keyperArg,
        Attacker attackerArg,
        SafeHelper safeHelperArg,
        uint256 numberOwners
    ) public {
        keyper = keyperArg;
        attacker = attackerArg;
        safeHelper = safeHelperArg;
        initOnwers(numberOwners);
    }

    /// function to encode signatures for Attack KeyperTx
    /// @param org Organization address
    /// @param superSafe Super Safe address
    /// @param targetSafe Target Safe address
    /// @param to Address to send the transaction
    /// @param value Value to send
    /// @param data Data payload
    /// @param operation Operation type
    /// @return signatures Packed signatures data (v, r, s)
    function encodeSignaturesForAttackKeyperTx(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org, superSafe, targetSafe, to, value, data, operation, nonce
        );

        uint256 threshold = attacker.getThreshold();
        address[] memory owners = attacker.getOwners();
        address[] memory sortedOwners = sortAddresses(owners);

        uint256[] memory ownersPKFromAttacker = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            ownersPKFromAttacker[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(ownersPKFromAttacker, txHashed);

        return signatures;
    }

    /// function to set Attacker Tree for the organization
    /// @param _orgName Name of the organization
    /// @return orgHash, orgAddr, attackerSafe, victim
    function setAttackerTree(string memory _orgName)
        public
        returns (bytes32, address, address, address)
    {
        safeHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(safeHelper.safeWallet());
        address orgAddr = keyperSafes[_orgName];

        safeHelper.updateSafeInterface(address(attacker));
        string memory nameAttacker = "Attacker";
        keyperSafes[nameAttacker] = address(attacker);

        address attackerSafe = keyperSafes[nameAttacker];
        bytes32 orgHash = keccak256(abi.encodePacked(_orgName));
        uint256 rootOrgId = keyper.getSquadIdBySafe(orgHash, orgAddr);

        vm.startPrank(attackerSafe);
        keyper.addSquad(rootOrgId, nameAttacker);
        vm.stopPrank();

        address victim = safeHelper.newKeyperSafe(2, 1);
        string memory nameVictim = "Victim";
        keyperSafes[nameVictim] = address(victim);
        uint256 attackerSquadId = keyper.getSquadIdBySafe(orgHash, attackerSafe);

        vm.startPrank(victim);
        keyper.addSquad(attackerSquadId, nameVictim);
        vm.stopPrank();
        uint256 victimSquadId = keyper.getSquadIdBySafe(orgHash, victim);

        vm.deal(victim, 100 gwei);

        vm.startPrank(orgAddr);
        keyper.setRole(
            DataTypes.Role.SAFE_LEAD, address(attackerSafe), victimSquadId, true
        );
        vm.stopPrank();

        return (orgHash, orgAddr, attackerSafe, victim);
    }
}
