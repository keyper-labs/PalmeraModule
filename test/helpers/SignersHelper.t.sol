// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

/// @notice Helper contract handling signers
/// @title SignersHelper
/// @custom:security-contact general@palmeradao.xyz
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

    /// function to initialize the owners
    /// @param numberOwners number of owners to initialize
    function initOnwers(uint256 numberOwners) public {
        initValidOnwers(numberOwners);
        initInvalidOnwers(30);
    }

    /// function to initialize the valid owners
    /// @param numberOwners number of valid owners to initialize
    function initValidOnwers(uint256 numberOwners) internal {
        privateKeyOwners = new uint256[](numberOwners);
        for (uint256 i; i < numberOwners; ++i) {
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

    /// function to initialize the invalid owners
    /// @param numberOwners number of invalid owners to initialize
    function initInvalidOnwers(uint256 numberOwners) internal {
        invalidPrivateKeyOwners = new uint256[](numberOwners);
        for (uint256 i; i < numberOwners; ++i) {
            // Start derivation after correct ones
            uint256 pk = i + numberOwners;
            address publicKey = vm.addr(pk);
            invalidOwnersPK[publicKey] = pk;
            invalidPrivateKeyOwners[i] = pk;
        }
    }

    /// function to get the owners
    /// @return amount of owners initialized
    function getOwnersUsed() public view returns (uint256) {
        return countUsed;
    }

    /// function to update the count of owners
    /// @param used amount of owners used
    function updateCount(uint256 used) public {
        countUsed = used;
    }
}
