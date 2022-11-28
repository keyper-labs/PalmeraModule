pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {Constants} from "../../src/Constants.sol";
import {console} from "forge-std/console.sol";

/// @title AttackerHelper
/// @custom:security-contact general@palmeradao.xyz
contract AttackerHelper is Test, SignDigestHelper, SignersHelper, Constants {
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

        vm.startPrank(attackerSafe);
        keyper.addGroup(orgAddr, orgAddr, nameAttacker);
        vm.stopPrank();

        address victim = gnosisHelper.newKeyperSafe(2, 1);
        string memory nameVictim = "Victim";
        keyperSafes[nameVictim] = address(victim);

        vm.startPrank(victim);
        keyper.addGroup(orgAddr, attackerSafe, nameVictim);
        vm.stopPrank();

        vm.deal(victim, 100 gwei);

        vm.startPrank(orgAddr);
        keyper.setRole(
            Role.SAFE_LEAD, address(attackerSafe), address(victim), true
        );
        vm.stopPrank();

        return (orgAddr, attackerSafe, victim);
    }
}
