// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

/// @title Library DataTypes
/// @custom:security-contact general@palmeradao.xyz
library DataTypes {
    /// @dev typos of Roles into Keyper Modules
    enum Role {
        SAFE_LEAD,
        SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
        SAFE_LEAD_MODIFY_OWNERS_ONLY,
        SUPER_SAFE,
        ROOT_SAFE
    }
    /// @dev typos of groups into Keyper Modules
    enum Tier {
        GROUP, // 0
        ROOT // 1
    }
    /// @devStruct for Group
    /// @param tier Kind of the group (at the momento only GROUP or ROOT)
    /// @param name String name of the group (any tier of group)
    /// @param lead Address of Safe Lead of the group (Safe Lead Role)
    /// @param safe Address of Safe of the group (Safe Role)
    /// @param child Array of ID's members of the group
    /// @param superSafe ID of Superior Group (superSafe Role)
    struct Group {
        Tier tier;
        string name;
        address lead;
        address safe;
        uint256[] child;
        uint256 superSafe;
    }
}
