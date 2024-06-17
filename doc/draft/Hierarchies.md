# Summary of `Hierarchies` Contract

## Overview

The `Hierarchies` contract tests the functionality of hierarchical structures within the Palmera Module. The contract is designed to ensure that all significant actions, such as registering organizations and safes and updating hierarchical structures, are performed correctly. This document provides an overview of the various unit tests implemented in the contract to verify these functionalities.

## Unit Tests

### Setup Function

- **Function**: `setUp`
- **Purpose**: Deploy all necessary contracts and initialize the testing environment.
- **Details**:
  - Deploys contracts with `DeployHelper.deployAllContracts(210)`.

### Test Cases

#### Test Case: `testRegisterRootOrg`

- **Function**: `testRegisterRootOrg`
- **Purpose**: Validate the registration of a root organization within the Palmera Module.
- **Steps**:
  - **Register Root Organization**: Calls `registerOrgTx` to register a root organization with the name `orgName`.
  - **Assertions**:
    - Verifies that the organization is successfully registered.
    - Checks that the organization hash matches the expected value.
    - Retrieves and verifies the Safe information for the root Safe.
    - Ensures the Safe has the correct tier, name, lead address, Safe address, and no children.
    - Confirms the organization is marked as registered.
    - Verifies that the Safe has the `ROOT_SAFE` role.

#### Test Case: `testAddSafe`

- **Function**: `testAddSafe`
- **Purpose**: Verify the addition of a Safe to a root organization within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Retrieve Safe Information**: Retrieves information about the Safe (`safeIdA1`) using `getSafeInfo`.
  - **Assertions**:
    - Ensures the Safe has the correct tier, name, lead address, Safe address, and super Safe ID.
    - Confirms the Safe is added as a child to the root organization.

#### Test Case: `testAddMultipleSafes`

- **Function**: `testAddMultipleSafes`
- **Purpose**: Verify the addition of multiple Safes to a root organization within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and Multiple Safes**: Uses `setupRootOrgAndTwoSafes` to set up a root organization and two Safes (`safeIdA1` and `safeIdA2`).
  - **Retrieve Safe Information**: Retrieves information about the Safes (`safeIdA1` and `safeIdA2`) using `getSafeInfo`.
  - **Assertions**:
    - Ensures each Safe has the correct tier, name, lead address, Safe address, and super Safe ID.
    - Confirms each Safe is added as a child to the root organization.

#### Test Case: `testRemoveSafe`

- **Function**: `testRemoveSafe`
- **Purpose**: Verify the removal of a Safe from a root organization within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Remove Safe**: Calls `removeSafeTx` to remove the Safe (`safeIdA1`).
  - **Assertions**:
    - Ensures the Safe is removed from the organization.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testTransferSafeOwnership`

- **Function**: `testTransferSafeOwnership`
- **Purpose**: Verify the transfer of Safe ownership within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Transfer Ownership**: Calls `transferSafeOwnershipTx` to transfer the ownership of the Safe (`safeIdA1`) to another address.
  - **Assertions**:
    - Ensures the ownership of the Safe is transferred successfully.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testPromoteSafeToRoot`

- **Function**: `testPromoteSafeToRoot`
- **Purpose**: Verify the promotion of a Safe to a root Safe within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Promote Safe**: Calls `promoteSafeToRootTx` to promote the Safe (`safeIdA1`) to a root Safe.
  - **Assertions**:
    - Ensures the Safe is promoted to a root Safe.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testDisconnectSafe`

- **Function**: `testDisconnectSafe`
- **Purpose**: Verify the disconnection of a Safe from a root organization within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Disconnect Safe**: Calls `disconnectSafeTx` to disconnect the Safe (`safeIdA1`).
  - **Assertions**:
    - Ensures the Safe is disconnected from the organization.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testUpdateSuperSafe`

- **Function**: `testUpdateSuperSafe`
- **Purpose**: Verify the update of a super Safe within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and Multiple Safes**: Uses `setupRootOrgAndTwoSafes` to set up a root organization and two Safes (`safeIdA1` and `safeIdA2`).
  - **Update Super Safe**: Calls `updateSuperSafeTx` to update the super Safe (`safeIdA1`) to another Safe (`safeIdA2`).
  - **Assertions**:
    - Ensures the super Safe is updated.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testWholeTreeRemoved`

- **Function**: `testWholeTreeRemoved`
- **Purpose**: Verify the removal of an entire tree of Safes within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and Multiple Safes**: Uses `setupRootOrgAndThreeSafes` to set up a root organization and three Safes (`safeIdA1`, `safeIdA2`, and `safeIdA3`).
  - **Remove Whole Tree**: Calls `removeWholeTreeTx` to remove the entire tree of Safes.
  - **Assertions**:
    - Ensures the whole tree of Safes is removed.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testUpdateNewLimit`

- **Function**: `testUpdateNewLimit`
- **Purpose**: Verify the update of the depth tree limit within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Update Depth Tree Limit**: Calls `updateNewLimitTx` to update the depth tree limit.
  - **Assertions**:
    - Ensures the depth tree limit is updated.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testAddToAllowList`

- **Function**: `testAddToAllowList`
- **Purpose**: Verify the addition of addresses to the allow list within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Add to Allow List**: Calls `addToAllowListTx` to add addresses to the allow list.
  - **Assertions**:
    - Ensures addresses are added to the allow list.
    - Verifies the Safe information is updated accordingly.

#### Test Case: `testDropFromAllowList`

- **Function**: `testDropFromAllowList`
- **Purpose**: Verify the removal of addresses from the allow list within the Palmera Module.
- **Steps**:
  - **Setup Root Organization and One Safe**: Uses `setupRootOrgAndOneSafe` to set up a root organization and one Safe (`safeIdA1`).
  - **Drop from Allow List**: Calls `dropFromAllowListTx` to remove addresses from the allow list.
  - **Assertions**:
    - Ensures addresses are removed from the allow list.
    - Verifies the Safe information is updated accordingly.

## Conclusions

The `Hierarchies` contract ensures that the hierarchical structure management within the Palmera Module is functioning correctly. By testing the
