# Summary of `EventsCheckers` Contract

## Overview

The `EventsCheckers` contract is a comprehensive test suite for validating event emissions within the PalmeraDAO ecosystem. The contract extends `DeployHelper` and is designed to ensure that all significant actions, such as creating organizations and safes, removing safes, and updating the structure of safes, emit the correct events. This document provides an overview of the various unit tests implemented in the contract to verify these event emissions.

## Unit Tests

### Setup Function

- **Function**: `setUp`
- **Purpose**: Deploy all necessary contracts and initialize the `owners` array with predefined addresses.
- **Details**:
  - Deploys contracts with `DeployHelper.deployAllContracts(90)`.
  - Initializes `owners` array with five addresses (`0xAAA`, `0xBBB`, `0xCCC`, `0xDDD`, `0xEEE`).

### Test Event: Register Root Organization

- **Function**: `testEventWhenRegisterRootOrg`
- **Purpose**: Validate that the `OrganisationCreated` event is emitted when a new root organization is registered.
- **Steps**:
  - Create a new Palmera Safe.
  - Emit `OrganisationCreated` event with the creator's address, organization hash, and organization name.
  - Register the organization and check if the event is emitted correctly.

### Test Event: Add Safe

- **Function**: `testEventWhenAddSafe`
- **Purpose**: Verify that the `SafeCreated` event is emitted when a new safe is added to an organization.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Create a new safe and emit `SafeCreated` with relevant details such as organization hash, safe ID, creator address, super safe ID, and safe name.

### Test Event: Remove Safe

- **Function**: `testEventWhenRemoveSafe`
- **Purpose**: Ensure the `SafeRemoved` event is emitted correctly when a safe is removed from an organization.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Add a new safe and emit `SafeCreated`.
  - Remove the safe and emit `SafeRemoved` with relevant details such as organization hash, safe ID, remover address, super safe ID, and safe name.

### Test Event: Register Root Safe

- **Function**: `testEventWhenRegisterRootSafe`
- **Purpose**: Validate that the `RootSafeCreated` event is emitted when a new root safe is registered.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Register a new root safe and emit `RootSafeCreated` with relevant details such as organization hash, root safe ID, creator address, root safe address, and root safe name.

### Test Event: Update Super Safe

- **Function**: `testEventWhenUpdateSuper`
- **Purpose**: Verify that the `SafeSuperUpdated` event is emitted when a safe's super safe is updated.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Register a new root safe and emit `RootSafeCreated`.
  - Add a new safe and emit `SafeCreated`.
  - Update the super safe and emit `SafeSuperUpdated` with relevant details such as organization hash, safe ID, updater address, old super safe ID, and new super safe ID.

### Test Event: Promote Safe to Root Safe

- **Function**: `testEventWhenPromoteRootSafe`
- **Purpose**: Ensure the `RootSafePromoted` event is emitted when a safe is promoted to a root safe.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Add a new safe and emit `SafeCreated`.
  - Add a child safe and emit `SafeCreated`.
  - Promote the safe to a root safe and emit `RootSafePromoted` with relevant details such as organization hash, safe ID, updater address, and safe name.

### Test Event: Disconnect Safe

- **Function**: `testEventWhenDisconnectSafe`
- **Purpose**: Validate that the `SafeDisconnected` event is emitted when a safe is disconnected from the organization.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Add a new safe and emit `SafeCreated`.
  - Remove the safe and emit `SafeRemoved`.
  - Disconnect the safe and emit `SafeDisconnected` with relevant details such as organization hash, safe ID, safe address, and disconnector address.

### Test Event: Execution on Behalf

- **Function**: `testEventWhenExecutionOnBehalf`
- **Purpose**: Verify that the `TxOnBehalfExecuted` event is emitted when a transaction is executed on behalf of a safe.
- **Steps**:
  - Set up root organization and one safe.
  - Encode and sign the transaction.
  - Execute the transaction on behalf and emit `TxOnBehalfExecuted` with relevant details such as organization hash, executor address, super safe address, target safe address, and result.

### Test Event: Remove Whole Tree

- **Function**: `testEventWhenRemoveWholeTree`
- **Purpose**: Ensure the `WholeTreeRemoved` event is emitted when an entire tree of safes is removed.
- **Steps**:
  - Set up an organization with a four-tier tree structure.
  - Remove the whole tree and emit `WholeTreeRemoved` with relevant details such as organization hash, root safe ID, remover address, and organization name.

### Test Event: Update New Limit

- **Function**: `testEventWhenUpdateNewLimit`
- **Purpose**: Validate that the `NewLimitLevel` event is emitted when the depth tree limit is updated.
- **Steps**:
  - Register a new organization and emit `OrganisationCreated`.
  - Add a new safe and emit `SafeCreated`.
  - Update the depth tree limit and emit `NewLimitLevel` with relevant details such as organization hash, root safe ID, updater address, old limit, and new limit.

### Test Event: Add Address to Allow/Deny List

- **Function**: `testEventWhenAddToList`
- **Purpose**: Verify that the `AddedToList` event is emitted when addresses are added to the allow/deny list.
- **Steps**:
  - Register a new organization.
  - Enable the allow list.
  - Add addresses to the list and emit `AddedToList` with the list of user addresses.

### Test Event: Drop Address from Allow/Deny List

- **Function**: `testEventWhenDropFromList`
- **Purpose**: Ensure the `DroppedFromList` event is emitted when an address is dropped from the allow/deny list.
- **Steps**:
  - Register a new organization.
  - Enable the allow list and add addresses to it.
  - Drop an address from the list and emit `DroppedFromList` with the user address.

## Conclusions

The `EventsCheckers` contract provides a robust suite of tests to ensure that all critical actions within the PalmeraDAO ecosystem are accurately reflected through event emissions. This verification is crucial for maintaining transparency, traceability, and security within the decentralized organization. By thoroughly testing event emissions for organization and safe management, the contract helps uphold the integrity of operations and enhances trust among participants.
