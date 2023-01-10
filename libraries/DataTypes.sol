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
    /// @dev typos of squads into Keyper Modules
    enum Tier {
        SQUAD, // 0
        ROOT, // 1
        REMOVED // 2
    }
    /// @devStruct for Squad
    /// @param tier Kind of the squad (at the momento only squad or ROOT)
    /// @param name String name of the squad (any tier of squad)
    /// @param lead Address of Safe Lead of the squad (Safe Lead Role)
    /// @param safe Address of Safe of the squad (Safe Role)
    /// @param child Array of ID's members of the squad
    /// @param superSafe ID of Superior Squad (superSafe Role)
    struct Squad {
        Tier tier;
        string name;
        address lead;
        address safe;
        uint256[] child;
        uint256 superSafe;
    }
}
