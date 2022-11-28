// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {DataTypes} from "./DataTypes.sol";

library Errors {
    /// @dev Errors Keyper Modules
    error OrgNotRegistered(bytes32 org);
    error GroupNotRegistered(uint256 group);
    error SuperSafeNotRegistered(uint256 superSafe);
    error SafeNotRegistered(address safe);
    error NotAuthorizedAddOwnerWithThreshold();
    error NotAuthorizedRemoveGroupFromOtherTree();
    error NotAuthorizedExecOnBehalf();
    error NotAuthorizedAsNotSafeLead();
    error NotAuthorizedAsNotSuperSafe();
    error NotAuthorizedUpdateNonChildrenGroup();
    error NotAuthorizedSetRoleAnotherTree();
    error OwnerNotFound();
    error OwnerAlreadyExists();
    error CreateSafeProxyFailed();
    error InvalidThreshold();
    error TxExecutionModuleFaild();
    error ChildAlreadyExist();
    error InvalidGnosisSafe(address safe);
    error InvalidGnosisRootSafe(address safe);
    error InvalidGroupId();
    error SetRoleForbidden(DataTypes.Role role);
    error OrgAlreadyRegistered(bytes32 safe);
    error GroupAlreadyRegistered();
    error SafeAlreadyRegistered(address safe);
    error EmptyName();
    error UserNotGroup(address user);
    /// @dev Errors Module DenyHelpers
    error ZeroAddressProvided();
    error InvalidAddressProvided();
    error UserAlreadyOnList();
    error AddresNotAllowed();
    error AddressDenied();
    error DenyHelpersDisabled();
    error ListEmpty();
}
