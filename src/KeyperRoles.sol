// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {Constants} from "./Constants.sol";

contract KeyperRoles is RolesAuthority, Constants {

    string public constant NAME = "Keyper Roles";
    string public constant VERSION = "0.2.0";

    constructor(address keyperModule)
        RolesAuthority(msg.sender, Authority(address(0)))
    {
        setupRoles(keyperModule);
    }

    /// Configure roles  access control on Authority
    function setupRoles(address keyperModule) internal {
        /// Role 0 - AdminAddOwner
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(ADMIN_ADD_OWNERS_ROLE, keyperModule, ADD_OWNER, true);

        /// Role 1 - AdminRemoveOwner
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            ADMIN_REMOVE_OWNERS_ROLE,
            keyperModule,
            REMOVE_OWNER,
            true
        );

        /// Transfer ownership of authority to keyper module
        setOwner(keyperModule);
    }
}
