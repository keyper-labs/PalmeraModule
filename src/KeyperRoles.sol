// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";

contract KeyperRoles is RolesAuthority {
    uint8 internal constant ADMIN_ADD_OWNERS_ROLE = 0;
    uint8 internal constant ADMIN_REMOVE_OWNERS_ROLE = 1;
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

    constructor(address keyperModule)
        RolesAuthority(msg.sender, Authority(address(0)))
    {
        setupRoles(keyperModule);
    }

    function setupRoles(address keyperModule) internal {
        /// Configure access control on Authority

        /// Role 0 - AdminAddOwner
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            ADMIN_ADD_OWNERS_ROLE,
            address(keyperModule),
            ADD_OWNER,
            true
        );

        /// Role 1 - AdminRemoveOwner
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            ADMIN_REMOVE_OWNERS_ROLE,
            address(keyperModule),
            REMOVE_OWNER,
            true
        );

        /// Transfer ownership of authority to address null to ensure inmutability of roles
        setOwner(address(0));
    }
}
