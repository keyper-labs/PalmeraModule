// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

/// @title Library DataTypes
/// @custom:security-contact general@palmeradao.xyz
/// @notice Data Types for the Palmera module
/// @dev Definition of the Data Types for the Palmera Module
library DataTypes {
    /// @dev typos of Roles into Palmera Modules
    enum Role {
        SAFE_LEAD,
        SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
        SAFE_LEAD_MODIFY_OWNERS_ONLY,
        SUPER_SAFE,
        ROOT_SAFE
    }
    /// @dev typos of safes into Palmera Modules
    enum Tier {
        SAFE, // 0
        ROOT, // 1
        REMOVED // 2

    }
    /// @dev Struct for Safe
    /// @param tier Kind of the safe (at the momento only safe or ROOT)
    /// @param name String name of the safe (any tier of safe)
    /// @param lead Address of Safe Lead of the safe (Safe Lead Role)
    /// @param safe Address of Safe Wallet (Safe Role)
    /// @param child Array of ID's members of the safe
    /// @param superSafe ID of Superior Safe (superSafe Role)

    struct Safe {
        Tier tier;
        string name;
        address lead;
        address safe;
        uint256[] child;
        uint256 superSafe;
    }
}
