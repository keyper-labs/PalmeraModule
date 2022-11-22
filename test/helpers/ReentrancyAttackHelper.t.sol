pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
import {Attacker} from "../../src/ReentrancyAttack.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {console} from "forge-std/console.sol";

contract AttackerHelper is Test, SignDigestHelper, SignersHelper {
    KeyperModule public keyper;
    Attacker public attacker;

    function initHelper(
        KeyperModule _keyper,
        Attacker _attacker,
        uint256 numberOwners
    ) public {
        keyper = _keyper;
        attacker = _attacker;
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
}
