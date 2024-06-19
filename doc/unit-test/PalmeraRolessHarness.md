# PalmeraRoleHarness Unit Tests

## Contract Overview

`PalmeraRolesTest` inherits from `DeployHelper`, focusing on testing role management functionalities of the Palmera Module.

## Setup

- Uses `DeployHelper.deployAllContracts(90)` to set up the testing environment.

## Test Cases

### 1. testCan_PalmeraModule_Setup_RoleContract

- Verifies correct setup of the role contract by Palmera Module.
- Checks SAFE_LEAD role capabilities and role authority ownership.

### 2. testCan_ROOT_SAFE_SetRole_ROOT_SAFE_When_RegisterOrg

- Ensures ROOT_SAFE can set ROOT_SAFE role when registering an organization.
- Verifies ROOT_SAFE role capabilities.

### 3. testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_EAO

- Verifies ROOT_SAFE can assign SAFE_LEAD role to an Externally Owned Account (EOA).
- Checks role assignment and recognition.

### 4. testCan_ROOT_SAFE_SetRole_SAFE_LEAD_to_SAFE

- Tests ROOT_SAFE assigning SAFE_LEAD role to another Safe.
- Verifies role assignment to a new Safe.

### 5. testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EAO

- Ensures ROOT_SAFE cannot assign ROOT_SAFE role to an EOA.
- Expects revert with SetRoleForbidden error.

### 6. testCannot_SUPER_SAFE_SetRole_SAFE_LEAD_to_EAO

- Verifies SUPER_SAFE cannot assign SAFE_LEAD role to an EOA.
- Expects revert with InvalidRootSafe error.

### 7. testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_SAFE

- Ensures ROOT_SAFE cannot assign SUPER_SAFE role to another Safe.
- Expects revert with SetRoleForbidden error.

### 8. testCannot_ROOT_SAFE_SetRole_SUPER_SAFE_to_EAO

- Verifies ROOT_SAFE cannot assign SUPER_SAFE role to an EOA.
- Expects revert with SetRoleForbidden error.

### 9. testCannot_ROOT_SAFE_SetRole_ROOT_SAFE_to_EOA_DifferentTree_Safe

- Ensures ROOT_SAFE cannot assign roles to EOAs in a different tree.
- Expects revert with NotAuthorizedSetRoleAnotherTree error.

## Key Observations

1. Clear role hierarchy (ROOT_SAFE, SUPER_SAFE, SAFE_LEAD) with specific permissions.
2. Cross-tree role assignments are prevented.
3. Different rules for assigning roles to EOAs versus Safes.
4. Thorough security checks for unauthorized role assignments.

## Conclusion

These tests comprehensively cover role management functionalities, validating both successful and prevented unauthorized assignments, demonstrating the robustness of the Palmera Module's role management system.
