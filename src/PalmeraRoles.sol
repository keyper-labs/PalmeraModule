// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {ValidAddress} from "./DenyHelper.sol";
import {Events} from "../libraries/Events.sol";

/// @title Palmera Roles
/// @custom:security-contact general@palmeradao.xyz
contract PalmeraRoles is RolesAuthority, ValidAddress {
    string public constant NAME = "Palmera Roles";
    string public constant VERSION = "0.2.0";

    constructor(address palmeraModule)
        RolesAuthority(_msgSender(), Authority(address(0)))
    {
        setupRoles(palmeraModule);
    }

    /// @notice Fallback function: called when someone sends ETH or calls a function that does not exist
    fallback() external {
        revert("Fallback function called");
    }

    /// @notice Receive function: called when someone sends ETH to the contract without data
    receive() external payable {
        revert("This contract does not accept ETH");
    }

    /// Configure roles access control on Authority
    function setupRoles(address palmeraModule)
        internal
        validAddress(palmeraModule)
    {
        /// Define Role 0 - SAFE_LEAD

        /// Target contract: PalmeraModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            palmeraModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            palmeraModule,
            Constants.REMOVE_OWNER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD),
            palmeraModule,
            Constants.EXEC_ON_BEHALF,
            true
        );

        /// Define Role 1 - SAFE_LEAD_EXEC_ON_BEHALF_ONLY
        /// Target contract: PalmeraModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY),
            palmeraModule,
            Constants.EXEC_ON_BEHALF,
            true
        );

        /// Define Role 2 - SAFE_LEAD_MODIFY_OWNERS_ONLY
        /// Target contract: PalmeraModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            palmeraModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY),
            palmeraModule,
            Constants.REMOVE_OWNER,
            true
        );

        /// Define Role 3 - SUPER_SAFE
        /// Target contract: PalmeraModule
        /// Auth function addOwnerWithThreshold
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.ADD_OWNER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function removeOwner
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.REMOVE_OWNER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.EXEC_ON_BEHALF,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function removeSafe
        setRoleCapability(
            uint8(DataTypes.Role.SUPER_SAFE),
            palmeraModule,
            Constants.REMOVE_SAFE,
            true
        );

        /// Define Role 4 - ROOT_SAFE
        /// Target contract: PalmeraModule
        /// Auth function setRole
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ROLE_ASSIGMENT,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function enable Allow List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ENABLE_ALLOWLIST,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function enable Deny List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ENABLE_DENYLIST,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function Disable Deny Helper
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DISABLE_DENY_HELPER,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function Add to The List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.ADD_TO_LIST,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function Remove from List
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DROP_FROM_LIST,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function updateSuper
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.UPDATE_SUPER_SAFE,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function createRootSafe
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.CREATE_ROOT_SAFE,
            true
        );
        /// Target contract: PalmeraModule
        /// Auth function updateDepthTreeLimit
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.UPDATE_DEPTH_TREE_LIMIT,
            true
        );

        /// Target contract: PalmeraModule
        /// Auth function disconnectedSafe
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.DISCONNECT_SAFE,
            true
        );

        /// Target contract: PalmeraModule
        /// Auth function promoteRoot
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.PROMOTE_ROOT,
            true
        );

        /// Target contract: PalmeraModule
        /// Auth function promoteRoot
        setRoleCapability(
            uint8(DataTypes.Role.ROOT_SAFE),
            palmeraModule,
            Constants.REMOVE_WHOLE_TREE,
            true
        );

        /// Transfer ownership of authority to palmera module
        setOwner(palmeraModule);
        emit Events.PalmeraModuleSetup(palmeraModule, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                       USER ROLE (OVERRIDE) ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// function to assign a role to a user
    /// @param user address of the user
    /// @param role uint8 role to assign
    /// @param enabled bool enable or disable the role
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
