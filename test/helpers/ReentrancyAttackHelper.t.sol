// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

contract AttackerHelper is Test, SignDigestHelper, SignersHelper {
    KeyperModule public keyper;
    GnosisSafeHelper public gnosisHelper;
    Attacker public attacker;

    mapping(string => address) public keyperSafes;

    function initHelper(
        KeyperModule keyperArg,
        Attacker attackerArg,
        GnosisSafeHelper gnosisHelperArg,
        uint256 numberOwners
    ) public {
        keyper = keyperArg;
        attacker = attackerArg;
        gnosisHelper = gnosisHelperArg;
        initOnwers(numberOwners);
    }

    function encodeSignaturesForAttackKeyperTx(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public returns (bytes memory) {
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            org, safe, to, value, data, operation, nonce
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

    function setAttackerTree(string memory _orgName)
        public
        returns (address, address, address)
    {
        gnosisHelper.registerOrgTx(_orgName);
        keyperSafes[_orgName] = address(gnosisHelper.gnosisSafe());
        address orgAddr = keyperSafes[_orgName];

        gnosisHelper.updateSafeInterface(address(attacker));
        string memory nameAttacker = "Attacker";
        keyperSafes[nameAttacker] = address(attacker);

        address attackerSafe = keyperSafes[nameAttacker];
        bytes32 orgHash = keccak256(abi.encodePacked(_orgName));
        uint256 rootOrgId = keyper.getGroupIdBySafe(orgHash, orgAddr);

        vm.startPrank(attackerSafe);
        keyper.addGroup(rootOrgId, nameAttacker);
        vm.stopPrank();

        address victim = gnosisHelper.newKeyperSafe(2, 1);
        string memory nameVictim = "Victim";
        keyperSafes[nameVictim] = address(victim);
        uint256 attackerGroupId = keyper.getGroupIdBySafe(orgHash, attackerSafe);

        vm.startPrank(victim);
        keyper.addGroup(attackerGroupId, nameVictim);
        vm.stopPrank();
        uint256 victimGroupId = keyper.getGroupIdBySafe(orgHash, victim);

        vm.deal(victim, 100 gwei);

        vm.startPrank(orgAddr);
        keyper.setRole(
            DataTypes.Role.SAFE_LEAD, address(attackerSafe), victimGroupId, true
        );
        vm.stopPrank();

        return (orgAddr, attackerSafe, victim);
    }
}
