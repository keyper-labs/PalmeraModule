# Technical Overview of Hardhat Unit Tests

## Overview

The unit tests for the Palmera Module are designed to ensure the correct deployment, setup, and interaction of various components within the module. The tests are structured using ths foundry framework, which provides a standardized approach to writing and executing tests.

## Helpers Contracts

- [DeployHelper](./unit-test/helpers/DeployHelper.md)
- [PalmeraModuleHelper](./unit-test/helpers/PalmeraModuleHelper.md)
- [PalmeraSafeBuilder](./unit-test/helpers/PalmeraSafeBuilder.md)
- [ReentrancyAttack](./unit-test/helpers/ReentrancyAttackHelper.md)
- [SafeHelper](./unit-test/helpers/SafeHelper.md)
- [SignDigest](./unit-test/helpers/SignDigestHelper.md)
- [SignersHelpers](./unit-test/helpers/SignersHelpers.md)
- [SkipSafeHelper](./unit-test/helpers/SkipSafeHelper.md)
- [SkipSafeEnv](./unit-test/helpers/SkipSafeEnv.md)

## Unit-Test Cases

- [Deny Helper Palmera Module](./unit-test/DenyHelperPalmeraModuleTest.md)
- [Deploy](./unit-test/Deploy.md)
- [Deploy Safe](./unit-test/DeploySafe.md)
- [Enable Guard](./unit-test/EnableGuard.md)
- [Enable Module](./unit-test/EnableModule.md)
- [Deploy](./unit-test/Deploy.md)
- [EventsCheck](./unit-test/EventsCheck.md)
- [ExecTransactionOnBehalf](./unit-test/ExecTransactionOnBehalf.md)
- [Hierarchies](./unit-test/Hierarchies.md)
- [Keyper Safe](./unit-test/KeyperSafe.md)
- [Modify Safe Owners](./unit-test/ModifySafeOwners.md)
- [Palmera Guard](./unit-test/PalmeraGuardTest.md)
- [Palmera Guard Fallback](./unit-test/PalmeraGuardTestFallbackAndReceive.md)
- [Palmera Module Fallback](./unit-test/PalmeraModuleTestFallbackAndReceive.md)
- [Palmera Roles Harness](./unit-test/PalmeraRolesHarness.md)
- [Palmera Roles](./unit-test/PalmeraRolesTest.md)
- [Palmera Roles Fallback](./unit-test/PalmeraRolesTestFallbackAndReceive.md)
- [SkipStressTestStorage](./unit-test/SkipStressTestStorage.md)
