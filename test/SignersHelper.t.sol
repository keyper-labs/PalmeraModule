pragma solidity ^0.8.0;
import "forge-std/Test.sol";

contract SignersHelper is Test {
    uint256[] public privateKeyOwners;
    mapping(address => uint256) public ownersPK;

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
    }
}
