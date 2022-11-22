// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {ConstantsV2} from "./ConstantsV2.sol";
import {DenyHelperV2} from "./DenyHelperV2.sol";

contract KeyperRolesV2 is RolesAuthority, ConstantsV2, DenyHelperV2 {
    string public constant NAME = "Keyper Roles";
    string public constant VERSION = "0.2.0";

    /// @dev Event when a new keyperModule is setting up
    event KeyperModuleSetup(address keyperModule, address caller);

    constructor(address keyperModule)
        RolesAuthority(_msgSender(), Authority(address(0)))
    {
        setupRoles(keyperModule);
    }

    /// Configure roles access control on Authority
    function setupRoles(address keyperModule)
        internal
        validAddress(keyperModule)
    {
        /// Define Role 0 - SAFE_LEAD

        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(uint8(Role.SAFE_LEAD), keyperModule, ADD_OWNER, true);
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(Role.SAFE_LEAD), keyperModule, REMOVE_OWNER, true
        );
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(Role.SAFE_LEAD), keyperModule, EXEC_ON_BEHALF, true
        );

        /// Define Role 1 - SAFE_LEAD_EXEC_ON_BEHALF_ONLY
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            keyperModule,
            EXEC_ON_BEHALF,
            true
        );

        /// Define Role 2 - SAFE_LEAD_MODIFY_OWNERS_ONLY
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            ADD_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            REMOVE_OWNER,
            true
        );

        /// Define Role 3 - ROOT_SAFE
        /// Target contract: KeyperModule
        /// Auth function setRole
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, ROLE_ASSIGMENT, true
        );
        /// Target contract: KeyperModule
        /// Auth function enable Allow List
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, ENABLE_ALLOWLIST, true
        );
        /// Target contract: KeyperModule
        /// Auth function enable Deny List
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, ENABLE_DENYLIST, true
        );
        /// Target contract: KeyperModule
        /// Auth function Disable Deny Helper
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, DISABLE_DENY_HELPER, true
        );
        /// Target contract: KeyperModule
        /// Auth function Add to The List
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, ADD_TO_LIST, true
        );
        /// Target contract: KeyperModule
        /// Auth function Remove from List
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, DROP_FROM_LIST, true
        );
        /// Target contract: KeyperModule
        /// Auth function updateSuper
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, UPDATE_SUPER_SAFE, true
        );
        /// Target contract: KeyperModule
        /// Auth function createRootSafeGroup
        setRoleCapability(
            uint8(Role.ROOT_SAFE), keyperModule, CREATE_ROOT_SAFE, true
        );

        /// Define Role 4 - SUPER_SAFE
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(uint8(Role.SUPER_SAFE), keyperModule, ADD_OWNER, true);
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(Role.SUPER_SAFE), keyperModule, REMOVE_OWNER, true
        );
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(Role.SUPER_SAFE), keyperModule, EXEC_ON_BEHALF, true
        );
        /// Target contract: KeyperModule
        /// Auth function removeGroup
        setRoleCapability(
            uint8(Role.SUPER_SAFE), keyperModule, REMOVE_GROUP, true
        );

        /// Transfer ownership of authority to keyper module
        setOwner(keyperModule);
        emit KeyperModuleSetup(keyperModule, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                       USER ROLE (OVERRIDE) ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function setUserRole(address user, uint8 role, bool enabled)
        public
        virtual
        override
        requiresAuth
    {
        if (enabled) {
            getUserRoles[user] |= bytes32(1 << role);
        } else {
            getUserRoles[user] &= ~bytes32(1 << role);
        }

        emit UserRoleUpdated(user, role, enabled);
    }
}
