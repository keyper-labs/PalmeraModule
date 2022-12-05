// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

/// @title Library Constants
/// @custom:security-contact general@palmeradao.xyz
library Constants {
    // Sentinel Owners for Gnosis Safe
    address internal constant SENTINEL_ADDRESS = address(0x1);
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

    bytes4 internal constant ADD_OWNER =
        bytes4(
            keccak256(
                bytes("addOwnerWithThreshold(address,uint256,address,bytes32)")
            )
        );
    bytes4 internal constant REMOVE_OWNER =
        bytes4(
            keccak256(
                bytes("removeOwner(address,address,uint256,address,bytes32)")
            )
        );

    bytes4 internal constant ROLE_ASSIGMENT =
        bytes4(keccak256(bytes("setRole(uint8,address,uint256,bool)")));

    bytes4 internal constant CREATE_ROOT_SAFE =
        bytes4(keccak256(bytes("createRootSafeGroup(address,string)")));

    bytes4 internal constant ENABLE_ALLOWLIST =
        bytes4(keccak256(bytes("enableAllowlist()")));

    bytes4 internal constant ENABLE_DENYLIST =
        bytes4(keccak256(bytes("enableDenylist()")));

    bytes4 internal constant DISABLE_DENY_HELPER =
        bytes4(keccak256(bytes("disableDenyHelper()")));

    bytes4 internal constant ADD_TO_LIST =
        bytes4(keccak256(bytes("addToList(address[])")));

    bytes4 internal constant DROP_FROM_LIST =
        bytes4(keccak256(bytes("dropFromList(address)")));

    bytes4 internal constant UPDATE_SUPER_SAFE =
        bytes4(keccak256(bytes("updateSuper(uint256,uint256)")));

    bytes4 internal constant EXEC_ON_BEHALF =
        bytes4(
            keccak256(
                bytes(
                    "execTransactionOnBehalf(bytes32,address,address,uint256,bytes,uint8,bytes)"
                )
            )
        );

    bytes4 internal constant REMOVE_GROUP =
        bytes4(keccak256(bytes("removeGroup(uint256)")));
}
