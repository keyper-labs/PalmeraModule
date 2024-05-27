// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {DataTypes} from "./DataTypes.sol";

/// @title Library DataTypes
/// @custom:security-contact general@palmeradao.xyz
library Errors {
    /// @notice Error codes for the Palmera module
    /// @dev Errors Palmera Modules
    /// @dev Error messages when the Org Hash (Dao's name) is not Registered
    error OrgNotRegistered(bytes32 org);
    /// @dev Error messages when the Squad(`squad`) is not Registered
    error SquadNotRegistered(uint256 squad);
    /// @dev Error messages when the Super safe Squad(`superSafe`) is not Registered
    error SuperSafeNotRegistered(uint256 superSafe);
    /// @dev Error messages when the Safe(`safe`) is not Registered
    error SafeNotRegistered(address safe);
    /// @dev Error messages when the Safe is not Autorized to Add Owner like Lead/Super/Root Safe
    error NotAuthorizedAddOwnerWithThreshold();
    /// @dev Error messages when the Safe is not Autorized to Remove Owner like Lead/Safe/Root Safe
    error NotAuthorizedRemoveSquadFromOtherTree();
    error NotAuthorizedRemoveSquadFromOtherOrg();
    error NotAuthorizedRemoveOwner();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedUpdateSquadToOtherOrg();
    /// @dev Error messages when try to disconnect Safe before remove it, and show the Safe's children Squad Id's
    error CannotDisconnectedSafeBeforeRemoveChild(uint256 children);
    /// @dev Error messages when try to remove Squad before remove it's children, and show the Squad's children Squad Id's
    error CannotRemoveSquadBeforeRemoveChild(uint256 children);
    error CannotDisablePalmeraModule(address module);
    error CannotDisablePalmeraGuard(address guard);
    error SquadAlreadyRemoved();
    /// @dev Error messages when the Caller is not Autorized to execute any action like Lead Safe
    error NotAuthorizedAsNotSafeLead();
    /// @dev Error messages when the Caller is not Autorized to execute any action like Super Safe
    error NotAuthorizedAsNotRootOrSuperSafe();
    /// @dev Error messages when the Root Safe is not Autorized Update Super Safe for a Squad in Another Tree
    error NotAuthorizedUpdateNonChildrenSquad();
    error NotAuthorizedUpdateNonSuperSafe();
    /// @dev Error messages when the Root Safe is not Autorized to Disconnect an Safe in Another Tree
    error NotAuthorizedDisconnectChildrenSquad();
    /// @dev Error messages when the Root Safe is not Autorized to Update a Role in a Squad in Another Tree
    error NotAuthorizedSetRoleAnotherTree();
    /// @dev Error messages the Owner is not Found into the Safe Owners
    error OwnerNotFound();
    /// @dev Error messages the Owner Already Exist into the Safe Owners
    error OwnerAlreadyExists();
    /// @dev Error messages when Fail try to create a new Safe with the Palmera Module Enabled
    error CreateSafeProxyFailed();
    /// @dev Error messages when Invalid Threshold is provided
    error InvalidThreshold();
    /// @dev Error messages when Try to Execute a Transaction On Behalf and Fail
    error TxExecutionModuleFailed();
    error PreviewModuleNotFound(address squad);
    /// @dev Error messages when Try to Execute a Transaction On Behalf and Fail
    error TxOnBehalfExecutedFailed();
    /// @dev Error messages when the caller is an Invalid Safe
    error InvalidSafe(address safe);
    /// @dev Error messages when the caller is an Invalid Root Safe
    error InvalidRootSafe(address safe);
    /// @dev Error messages when the Squad is an Invalid ID's
    error InvalidSquadId();
    /// @dev Error messages when the Try to Modify a Role Not Permitted
    error SetRoleForbidden(DataTypes.Role role);
    /// @dev Error messages when Org Already Registered
    error OrgAlreadyRegistered(bytes32 safe);
    /// @dev Error messages when Squad Already Registered
    error SquadAlreadyRegistered();
    /// @dev Error messages when Safe Already Registered
    error SafeAlreadyRegistered(address safe);
    /// @dev Error messages when the String Name is Empty
    error EmptyName();
    /// @dev Errors messages when Raised the Level Limit
    error TreeDepthLimitReached(uint256 limit);
    /// @dev Errors messages when New Limit is more than Max Limit or less than or Equal to actual value
    error InvalidLimit();
    /// @dev Errors Module DenyHelpers
    /// @dev Error messages when the Address is a Zero Address
    error ZeroAddressProvided();
    /// @dev Error messages when the Address is Invalid Address
    error InvalidAddressProvided();
    /// @dev Error messages when the Address is Already on the List
    error UserAlreadyOnList();
    /// @dev Error messages when the Address is Not Allowed
    error AddresNotAllowed();
    /// @dev Error messages when the Address is Denied
    error AddressDenied();
    /// @dev Error messages when the Deny Helper is Disabled
    error DenyHelpersDisabled();
    /// @dev Error messages when the List of Allow/Deny is Empty
    error ListEmpty();
}
