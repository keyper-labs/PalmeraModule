// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {Constants} from "./Constants.sol";
import {DenyHelper} from "./DenyHelper.sol";

contract KeyperRoles is RolesAuthority, Constants, DenyHelper {
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
        setRoleCapability(SAFE_LEAD, keyperModule, ADD_OWNER, true);

        /// Target contract: KeyperModule
        /// Auth function removeOwner
        setRoleCapability(SAFE_LEAD, keyperModule, REMOVE_OWNER, true);

        /// Target contract: KeyperModule
        /// Auth function execTransactionOnBehalf
        setRoleCapability(SAFE_LEAD, keyperModule, EXEC_ON_BEHALF, true);

        /// Transfer ownership of authority to keyper module
        setOwner(keyperModule);
        emit KeyperModuleSetup(keyperModule, _msgSender());
    }
}
