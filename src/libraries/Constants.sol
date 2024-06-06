// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

/// @title Library Constants
/// @custom:security-contact general@palmeradao.xyz
/// @notice Constants Definitions for the Palmera module
library Constants {
    /// @dev Sentinel Owners for Safe
    address internal constant SENTINEL_ADDRESS = address(0x1);
    /// @dev keccak256(
    ///     "EIP712Domain(uint256 chainId,address verifyingContract)"
    /// );
    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    /// @dev keccak256(
    ///     "PalmeraTx(address org,address superSafe,address targetSafe,address to,uint256 value,bytes data,uint8 operation,uint256 _nonce)"
    /// );
    bytes32 internal constant PALMERA_TX_TYPEHASH =
        0x5576bff5f05f6e5452f02e4fe418b1519cb08f54fae3564c3a4d2a4706584d4e;

    address internal constant FALLBACK_HANDLER =
        0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;
    /// @dev Signature for Roles and Permissions Management of Add Owner
    bytes4 internal constant ADD_OWNER = bytes4(
        keccak256(
            bytes("addOwnerWithThreshold(address,uint256,address,bytes32)")
        )
    );
    /// @dev Signature for Roles and Permissions Management of Remove Owner
    bytes4 internal constant REMOVE_OWNER = bytes4(
        keccak256(bytes("removeOwner(address,address,uint256,address,bytes32)"))
    );
    /// @dev Signature for Roles and Permissions Management of Role Assigment
    bytes4 internal constant ROLE_ASSIGMENT =
        bytes4(keccak256(bytes("setRole(uint8,address,uint256,bool)")));
    /// @dev Signature for Roles and Permissions Management of Create Root Safe
    bytes4 internal constant CREATE_ROOT_SAFE =
        bytes4(keccak256(bytes("createRootSafe(address,string)")));
    /// @dev Signature for Roles and Permissions Management of Enable Allowlist
    bytes4 internal constant ENABLE_ALLOWLIST =
        bytes4(keccak256(bytes("enableAllowlist()")));
    /// @dev Signature for Roles and Permissions Management of Enable Denylist
    bytes4 internal constant ENABLE_DENYLIST =
        bytes4(keccak256(bytes("enableDenylist()")));
    /// @dev Signature for Roles and Permissions Management of Disable Deny Helper
    bytes4 internal constant DISABLE_DENY_HELPER =
        bytes4(keccak256(bytes("disableDenyHelper()")));
    /// @dev Signature for Roles and Permissions Management of Add to List
    bytes4 internal constant ADD_TO_LIST =
        bytes4(keccak256(bytes("addToList(address[])")));
    /// @dev Signature for Roles and Permissions Management of Drop from List
    bytes4 internal constant DROP_FROM_LIST =
        bytes4(keccak256(bytes("dropFromList(address)")));
    /// @dev Signature for Roles and Permissions Management of Update Super Safe
    bytes4 internal constant UPDATE_SUPER_SAFE =
        bytes4(keccak256(bytes("updateSuper(uint256,uint256)")));
    /// @dev Signature for Roles and Permissions Management of Promote Root Safe
    bytes4 internal constant PROMOTE_ROOT =
        bytes4(keccak256(bytes("promoteRoot(uint256)")));
    /// @dev Signature for Roles and Permissions Management of Update Depth Tree Limit
    bytes4 internal constant UPDATE_DEPTH_TREE_LIMIT =
        bytes4(keccak256(bytes("updateDepthTreeLimit(uint256)")));
    /// @dev Signature for Roles and Permissions Management of Execution on Behalf
    bytes4 internal constant EXEC_ON_BEHALF = bytes4(
        keccak256(
            bytes(
                "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)"
            )
        )
    );
    /// @dev Signature for Roles and Permissions Management of Remove Safe
    bytes4 internal constant REMOVE_SAFE =
        bytes4(keccak256(bytes("removeSafe(uint256)")));
    /// @dev Signature for Roles and Permissions Management of Remove Whole Tree
    bytes4 internal constant REMOVE_WHOLE_TREE =
        bytes4(keccak256(bytes("removeWholeTree()")));
    /// @dev Signature for Roles and Permissions Management of Disconnect Safe
    bytes4 internal constant DISCONNECT_SAFE =
        bytes4(keccak256(bytes("disconnectSafe(uint256)")));

    /// @dev keccak256("guard_manager.guard.address")
    bytes32 internal constant GUARD_STORAGE_SLOT =
        0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    /// @dev bytes4(keccak256("isValidSignature(bytes,bytes)")
    bytes4 internal constant EIP1271_MAGIC_VALUE = 0x20c13b0b;
}
