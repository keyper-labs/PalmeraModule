pragma solidity ^0.8.0;
import "forge-std/Test.sol";

// Helper contract handling signers
contract SignersHelper is Test {
    // Array private keys
    uint256[] public privateKeyOwners;
    // Address => PK
    mapping(address => uint256) public ownersPK;
    // Invalid PK (no set as owners)
    uint256[] public invalidPrivateKeyOwners;
    // Address => PK (invalid)
    mapping(address => uint256) public invalidOwnersPK;
    // CountUsed
    uint256 public countUsed;

    function initOnwers(uint256 numberOwners) public {
        privateKeyOwners = new uint256[](numberOwners);
        for (uint256 i = 0; i < numberOwners; i++) {
            uint256 pk = i;
            // Avoid deriving public key from 0x address
            if (i == 0) {
                pk = 0xaaa;
            }
            address publicKey = vm.addr(pk);
            ownersPK[publicKey] = pk;
            privateKeyOwners[i] = pk;
        }

        invalidPrivateKeyOwners = new uint256[](numberOwners);
        for (uint256 i = 0; i < numberOwners; i++) {
            // Start derivation after correct ones
            uint256 pk = i + numberOwners;
            address publicKey = vm.addr(pk);
            invalidOwnersPK[publicKey] = pk;
            invalidPrivateKeyOwners[i] = pk;
        }
    }

    function updateCount(uint256 used) public {
        countUsed = used;
    }
}
