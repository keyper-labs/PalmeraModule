# Summary of Unit Tests for the `PalmeraModuleSafe` Contract

## Overview

This document provides a detailed summary of the unit tests conducted on the `PalmeraModuleSafe` contract using the `TestPalmeraSafe` test suite. These tests cover various functionalities including authority checks, allow/deny list validations, organization registration, safe removal operations, and permission validations. The purpose of these tests is to ensure the robustness and correctness of the `PalmeraModuleSafe` contract, which is critical for managing hierarchical organizations and their associated safes in the PalmeraDAO ecosystem.

## Initial Setup

- **`setUp` Function**: Deploys all necessary contracts for the tests with a configuration parameter of `90`.

## Authority Tests

- **`testAuthorityAddress`**: Checks that the authority of the Palmera module is equal to `palmeraRolesDeployed`.

## Allow/Deny List Tests

### `execTransactionOnBehalf` with Allow List

- **`testRevertSuperSafeExecOnBehalfIsNotAllowList`**:
  - **Condition**: `safeA1` is not on the allow list.
  - **Expected Result**: The transaction is reverted with `Errors.AddresNotAllowed`.

### `execTransactionOnBehalf` with Deny List

- **`testRevertSuperSafeExecOnBehalfIsDenyList`**:
  - **Condition**: `safeA1` is on the deny list.
  - **Expected Result**: The transaction is reverted with `Errors.AddressDenied`.

- **`testDisableDenyHelperList`**:
  - **Condition**: The deny list is disabled after being enabled.
  - **Expected Result**: The transaction executes successfully.

## `registerOrg` Tests

- **`testRevertAuthForRegisterOrgTx`**:
  - **Condition**: An address without roles attempts to register an organization.
  - **Expected Result**: The transaction is reverted with the message "UNAUTHORIZED".

## `removeSafe` Tests

- **`testCan_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_SameTree`**:
  - **Caller**: `ROOT_SAFE`
  - **Target**: `safeA1` in the same tree.
  - **Expected Result**: `subSafeA1` is removed from `safeA1`'s children and becomes a direct child of the organization root.

- **`testCannot_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentTree`**:
  - **Caller**: `ROOT_SAFE`
  - **Target**: `safeB` in a different tree.
  - **Expected Result**: The transaction is reverted with `Errors.NotAuthorizedAsNotRootOrSuperSafe`.

- **`testCannot_RemoveSafe_ROOT_SAFE_as_SAFE_is_TARGETS_ROOT_DifferentOrg`**:
  - **Caller**: `ROOT_SAFE`
  - **Target**: `safeB` in a different organization.
  - **Expected Result**: The transaction is reverted with `Errors.NotAuthorizedAsNotRootOrSuperSafe`.

- **`testCan_RemoveSafe_SUPER_SAFE_as_SAFE_is_SUPER_SAFE_SameTree`**:
  - **Caller**: `SUPER_SAFE`
  - **Target**: `subSafeA1` in the same tree.
  - **Expected Result**: `subSafeA1` is removed successfully and no longer appears as a child.

- **`testCannot_RemoveSafe_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_DifferentTree`**:
  - **Caller**: `SUPER_SAFE`
  - **Target**: `safeB` in a different tree.
  - **Expected Result**: The transaction is reverted with `Errors.NotAuthorizedAsNotRootOrSuperSafe`.

- **`testCannot_RemoveSafe_SUPER_SAFE_as_SAFE_is_not_TARGET_SUPER_SAFE_SameTree`**:
  - **Caller**: `SUPER_SAFE`
  - **Target**: `subSubSafeA1` in the same tree but not a direct child.
  - **Expected Result**: The transaction is reverted with `Errors.NotAuthorizedAsNotRootOrSuperSafe`.

- **`testRemoveSafeAndCheckDisables`**:
  - **Caller**: `ROOT_SAFE`
  - **Target**: `safeA1` in the same tree.
  - **Expected Result**: `safeA1` is removed, and all associated roles are disabled.

## Permission Over Target Tests

- **`testCan_hasNotPermissionOverTarget_is_root_of_target`**:
  - **Caller**: `ROOT_SAFE`
  - **Target**: `safeA1` in the same tree.
  - **Expected Result**: The caller has permission over the target.

- **`testCan_hasNotPermissionOverTarget_is_not_root_of_target`**:
  - **Caller**: `SUPER_SAFE`
  - **Target**: `ROOT_SAFE` in the same tree.
  - **Expected Result**: The caller does not have permission over the target.

- **`testCan_hasNotPermissionOverTarget_is_super_safe_of_target`**:
  - **Caller**: `SUPER_SAFE`
  - **Target**: `subSafeA1` in the same tree.
  - **Expected Result**: The caller has permission over the target.

- **`testCan_hasNotPermissionOverTarget_is_not_super_safe_of_target`**:
  - **Caller**: `CHILD_SAFE`
  - **Target**: `SUPER_SAFE` in the same tree.
  - **Expected Result**: The caller does not have permission over the target.

## Conclusions

The unit tests for the `PalmeraModuleSafe` contract cover a comprehensive range of scenarios to validate the contract's functionality and security. The tests ensure that:

- The authority and role-based permissions are correctly implemented and enforced.
- Transactions adhere to the allow and deny lists, preventing unauthorized actions.
- Safe removal operations respect organizational hierarchies and permissions.
- Role and permission checks accurately determine the ability of entities to interact with each other within the organization's structure.