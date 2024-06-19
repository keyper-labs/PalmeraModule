# Technical Overview of Hardhat Unit Tests

## Overview

The unit tests for the Palmera Module are designed to ensure the correct deployment, setup, and interaction of various components within the module. The tests are structured using ths foundry framework, which provides a standardized approach to writing and executing tests.

## Helpers Contracts

- [DeployHelper](./draft/helpers/DeployHelper.md)
- [PalmeraModuleHelper](./draft/helpers/PalmeraModuleHelper.md)
- [PalmeraSafeBuilder](./draft/helpers/PalmeraSafeBuilder.md)
- [ReentrancyAttack](./draft/helpers/ReentrancyAttackHelper.md)
- [SafeHelper](./draft/helpers/SafeHelper.md)
- [SignDigest](./draft/helpers/SignDigestHelper.md)
- [SignersHelpers](./draft/helpers/SignersHelpers.md)
- [SkipSafeHelper](./draft/helpers/SkipSafeHelper.md)
- [SkipSafeEnv](./draft/helpers/SkipSafeEnv.md)

## Unit-Test Cases

- [Deny Helper Palmera Module](./draft/DenyHelperPalmeraModuleTest.md)
- [Deploy](./draft/Deploy.md)
- [Deploy Safe](./draft/DeploySafe.md)
- [Enable Guard](./draft/EnableGuard.md)
- [Enable Module](./draft/EnableModule.md)
- [Deploy](./draft/Deploy.md)
- [EventsCheck](./draft/EventsCheck.md)
- [ExecTransactionOnBehalf](./draft/ExecTransactionOnBehalf.md)
- [Hierarchies](./draft/Hierarchies.md)
- [Keyper Safe](./draft/KeyperSafe.md)
- [Modify Safe Owners](./draft/ModifySafeOwners.md)
- [Palmera Guard](./draft/PalmeraGuardTest.md)
- [Palmera Guard Fallback](./draft/PalmeraGuardTestFallbackAndReceive.md)
- [Palmera Module Fallback](./draft/PalmeraModuleTestFallbackAndReceive.md)
- [Palmera Roles Harness](./draft/PalmeraRolesHarness.md)
- [Palmera Roles](./draft/PalmeraRolesTest.md)
- [Palmera Roles Fallback](./draft/PalmeraRolesTestFallbackAndReceive.md)
- [SkipStressTestStorage](./draft/SkipStressTestStorage.md)
