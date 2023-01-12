// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {DenyHelper} from "./DenyHelper.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Events} from "../libraries/Events.sol";

/// @title Keyper Roles
/// @custom:security-contact general@palmeradao.xyz
contract KeyperRoles is RolesAuthority, DenyHelper {
    string public constant NAME = "Keyper Roles";
    string public constant VERSION = "0.2.0";

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
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            keyperModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            keyperModule,
            Constants.REMOVE_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            keyperModule,
            Constants.EXEC_ON_BEHALF,
            true
        );

        /// Define Role 1 - SAFE_LEAD_EXEC_ON_BEHALF_ONLY
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            keyperModule,
            Constants.EXEC_ON_BEHALF,
            true
        );

        /// Define Role 2 - SAFE_LEAD_MODIFY_OWNERS_ONLY
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            keyperModule,
            Constants.REMOVE_OWNER,
            true
        );

        /// Define Role 3 - SUPER_SAFE
        /// Target contract: KeyperModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.REMOVE_OWNER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.EXEC_ON_BEHALF,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function removeSquad
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            keyperModule,
            Constants.REMOVE_SQUAD,
            true
        );

        /// Define Role 4 - ROOT_SAFE
        /// Target contract: KeyperModule
        /// Auth function setRole
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ROLE_ASSIGMENT,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function enable Allow List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ENABLE_ALLOWLIST,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function enable Deny List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ENABLE_DENYLIST,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function Disable Deny Helper
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DISABLE_DENY_HELPER,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function Add to The List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.ADD_TO_LIST,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function Remove from List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DROP_FROM_LIST,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function updateSuper
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.UPDATE_SUPER_SAFE,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function createRootSafeSquad
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.CREATE_ROOT_SAFE,
            true
        );
        /// Target contract: KeyperModule
        /// Auth function updateDepthTreeLimit
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.UPDATE_DEPTH_TREE_LIMIT,
            true
        );

        /// Target contract: KeyperModule
        /// Auth function disconnectedSafe
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            keyperModule,
            Constants.DISCONNECTED_SAFE,
            true
        );

        /// Transfer ownership of authority to keyper module
        setOwner(keyperModule);
        emit Events.KeyperModuleSetup(keyperModule, _msgSender());
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
