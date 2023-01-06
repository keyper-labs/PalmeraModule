// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {DataTypes} from "./DataTypes.sol";

/// @title Library DataTypes
/// @custom:security-contact general@palmeradao.xyz
library Errors {
    /// @notice Error codes for the Keyper module
    /// @dev Errors Keyper Modules
    /// @dev Error messages when the Org Hash (Dao's name) is not Registered
    error OrgNotRegistered(bytes32 org);
    /// @dev Error messages when the Group(`group`) is not Registered
    error GroupNotRegistered(uint256 group);
    /// @dev Error messages when the Super safe Group(`superSafe`) is not Registered
    error SuperSafeNotRegistered(uint256 superSafe);
    /// @dev Error messages when the Safe(`safe`) is not Registered
    error SafeNotRegistered(address safe);
    /// @dev Error messages when the Safe is not Autorized to Add Owner like Lead/Super/Root Safe
    error NotAuthorizedAddOwnerWithThreshold();
    /// @dev Error messages when the Safe is not Autorized to Remove Owner like Lead/Safe/Root Safe
    error NotAuthorizedRemoveGroupFromOtherTree();
    error NotAuthorizedRemoveGroupFromOtherOrg();
    error NotAuthorizedRemoveOwner();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedUpdateGroupToOtherOrg();
	error NotAuthorizedUpdateNonSuperSafe();
    /// @dev Error messages when try to disconnect Safe before remove it, and show the Safe's children Group Id's
    error CannotDisconnectedSafeBeforeRemoveChild(uint256 children);
	/// @dev Error messages when try to remove Group before remove it's children, and show the Group's children Group Id's
	error CannotRemoveGroupBeforeRemoveChild(uint256 children);
    error CannotDisableKeyperModule(address module);
    error CannotDisableKeyperGuard(address guard);
	error GroupAlreadyRemoved();
    /// @dev Error messages when the Caller is not Autorized to execute any action like Lead Safe
    error NotAuthorizedAsNotSafeLead();
    /// @dev Error messages when the Caller is not Autorized to execute any action like Super Safe
    error NotAuthorizedAsNotSuperSafe();
    /// @dev Error messages when the Root Safe is not Autorized Update Super Safe for a Group in Another Tree
    error NotAuthorizedUpdateNonChildrenGroup();
    /// @dev Error messages when the Root Safe is not Autorized to Disconnect an Safe in Another Tree
    error NotAuthorizedDisconnectedChildrenGroup();
    /// @dev Error messages when the Root Safe is not Autorized to Update a Role in a Group in Another Tree
    error NotAuthorizedSetRoleAnotherTree();
    /// @dev Error messages the Owner is not Found into the Safe Owners
    error OwnerNotFound();
    /// @dev Error messages the Owner Already Exist into the Safe Owners
    error OwnerAlreadyExists();
    /// @dev Error messages when Fail try to create a new Safe with the Keyper Module Enabled
    error CreateSafeProxyFailed();
    /// @dev Error messages when Invalid Threshold is provided
    error InvalidThreshold();
    /// @dev Error messages when Try to Execute a Transaction On Behalf and Fail
    error TxExecutionModuleFaild();
    /// @dev Error messages when Try to Execute a Transaction On Behalf and Fail
    error TxOnBehalfExecutedFailed();
    /// @dev Error messages when the caller is an Invalid Gnosis Safe
    error InvalidGnosisSafe(address safe);
    /// @dev Error messages when the caller is an Invalid Gnosis Root Safe
    error InvalidGnosisRootSafe(address safe);
    /// @dev Error messages when the Group is an Invalid ID's
    error InvalidGroupId();
    /// @dev Error messages when the Try to Modify a Role Not Permitted
    error SetRoleForbidden(DataTypes.Role role);
    /// @dev Error messages when Org Already Registered
    error OrgAlreadyRegistered(bytes32 safe);
    /// @dev Error messages when Group Already Registered
    error GroupAlreadyRegistered();
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
