// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

contract Constants {
    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "KeyperTx(address org,address safe,address to,uint256 value,bytes data,uint8 operation,uint256 nonce)"
    // );
    bytes32 internal constant KEYPER_TX_TYPEHASH =
        0xbb667b7bf67815e546e48fb8d0e6af5c31fe53b9967ed45225c9d55be21652da;

    address internal constant FALLBACK_HANDLER =
        0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

    uint8 internal constant ADMIN_ADD_OWNERS_ROLE = 0;
    uint8 internal constant ADMIN_REMOVE_OWNERS_ROLE = 1;
    uint8 internal constant SAFE_SET_ROLE = 2;

    bytes4 internal constant ADD_OWNER =
        bytes4(
            keccak256(
                bytes(
                    "addOwnerWithThreshold(address owner, uint256 _threshold)"
                )
            )
        );
    bytes4 internal constant REMOVE_OWNER =
        bytes4(
            keccak256(
                bytes(
                    "removeOwner(address prevOwner,address owner,uint256 _threshold)"
                )
            )
        );

    bytes4 internal constant SET_USER_ADMIN =
        bytes4(keccak256(bytes("setUserAdmin(address user)")));
}