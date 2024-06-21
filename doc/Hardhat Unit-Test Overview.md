# Technical Overview of Hardhat Unit Tests

## Overview

The unit tests for the Palmera Module are designed to ensure the correct deployment, setup, and interaction of various components within the module. The tests are structured using Mocha's `describe` and `it` methods, along with the `beforeEach` hook to set up the testing environment before each test case is executed.

## Setup Methods

The following methods are defined to deploy and configure the necessary contracts and environments:

### `deployLibraries`

Deploys all necessary libraries used by the Palmera Module.

- **Constants Library**: Provides constant values used throughout the module.
- **DataTypes Library**: Defines data types used in the module.
- **Errors Library**: Contains error messages for the module.
- **Events Library**: Manages events emitted by the module.

### `deployPalmeraEnvironment`

Deploys the Palmera environment, including the Palmera Module, Palmera Roles, and Palmera Guard.

- Uses the CREATE3Factory for predictable address deployments.
- Deploys the Palmera Roles contract with the Palmera Module address.
- Deploys the Palmera Module using CREATE3Factory.
- Deploys the Palmera Guard contract with the Palmera Module address.

### `deploySafeFactory`

Initializes the Safe Factory, deploys a specified number of Safe accounts, and sets up the Palmera Module and Guard for each Safe.

- Iterates through the specified number of Safe accounts.
- Deploys each Safe account and enables the Palmera Module and Guard.
- Verifies that the Palmera Module and Guard are correctly enabled in each Safe account.

### `deployLinealTreeOrg`

Deploys a linear organizational structure in the Palmera Module.

- Registers a basic organization in the Palmera Module.
- Updates the depth tree limit if necessary.
- Adds Safe accounts to the organization, forming a linear structure.

### `deploy1to3TreeOrg`

Deploys a 1-to-3 tree organizational structure in the Palmera Module.

- Registers a basic organization in the Palmera Module.
- Adds Safe accounts to the organization, forming a 1-to-3 tree structure.

## `beforeEach` Hook

The `beforeEach` hook is used to set up the testing environment before each test case is executed:

- Retrieves the list of signer accounts.
- Generates a salt value for deterministic deployments.
- Deploys necessary libraries.
- Deploys the Palmera environment, including the Palmera Module, Roles, and Guard.

## Detailed Explanation of Each Test Case

## Unit Test Overview

### Test Case 1 / 2: Create a Basic Linear Org in Palmera Module and Test ExecuteOnBehalf with EOA, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of a basic linear organizational structure in the Palmera Module and the execution of a transaction on behalf of the root Safe by another account (Externally Owned Account - EOA).
The test ensures that the Palmera Module's `execTransactionOnBehalf` function works as expected when the caller is an EOA.
This test case validates the core functionality of creating a linear organizational structure within the Palmera Module and the secure execution of transactions on behalf of the root Safe by an EOA.

#### Steps

1. **Deploy Safe Accounts**: Deploys Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys four Safe accounts with the specified version and setups the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first four Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic organization in the Palmera Module with a specified name and retrieves the organization hash.

4. **Transfer ETH to Last Safe Account**: Transfers 0.153 ETH from the last account to the last Safe account, ensuring the last Safe account has a balance for the transaction.

5. **Get Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function, preparing the necessary data for the transaction.

6. **Sign Transaction Hash**: Signs the transaction hash using the root Safe account to authorize the transaction.

7. **Execute Transaction On Behalf**: Executes the transaction on behalf of the root Safe account using another EOA. An EOA sends a transaction to the Palmera Module contract to execute the `execTransactionOnBehalf` function, ensuring the transaction is successful.

8. **Verify Balances**: Verifies the balances of the last Safe account and the last EOA before and after the transaction to confirm the transaction executed correctly.

### Test Case 3 / 4: Create a Basic Linear Org in Palmera Module and Test ExecuteOnBehalf with Another Safe, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of a basic linear organizational structure in the Palmera Module and the execution of a transaction on behalf of the root Safe by another Safe account. The test ensures that the Palmera Module's `execTransactionOnBehalf` function works as expected when the caller is another Safe account. This test verifies the interoperability and security of transactions within the hierarchical structure of the Palmera Module.
This test case validates the core functionality of creating a linear organizational structure within the Palmera Module and the secure execution of transactions on behalf of the root Safe by another Safe account. It ensures that the hierarchical structure and transaction mechanisms work correctly and securely.

#### Steps

1. **Deploy Safe Accounts**: Deploys three Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first three Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic organization in the Palmera Module with a specified name and retrieves the organization hash.

4. **Transfer ETH to Last Safe Account**: Transfers 0.153 ETH from the last account to the last Safe account, ensuring the last Safe account has a balance for the transaction.

5. **Get Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function, preparing the necessary data for the transaction.

6. **Sign Transaction Hash**: Signs the transaction hash using the root Safe account to authorize the transaction.

7. **Execute Transaction On Behalf**: Executes the transaction on behalf of the root Safe account using another Safe account. Another Safe account sends a transaction to the Palmera Module contract to execute the `execTransactionOnBehalf` function, ensuring the transaction is successful.

8. **Verify Balances**: Verifies the balances of the last Safe account and the last EOA before and after the transaction to confirm the transaction executed correctly.

### Test Case 5 / 6: Create a Basic 1-to-3 Org in Palmera Module and Test ExecuteOnBehalf with EOA, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of a basic 1-to-3 organizational structure in the Palmera Module and the execution of a transaction on behalf of the root Safe by another account (Externally Owned Account - EOA). The test ensures that the Palmera Module's `execTransactionOnBehalf` function works as expected when the caller is an EOA. This test verifies the interoperability and security of transactions within the hierarchical structure of the Palmera Module.

#### Steps

1. **Deploy Safe Accounts**: Deploys four Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first four Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic 1-to-3 organization in the Palmera Module with a specified name and retrieves the organization hash.

4. **Transfer ETH to Last Safe Account**: Transfers 0.153 ETH from the last account to the last Safe account, ensuring the last Safe account has a balance for the transaction.

5. **Get Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function, preparing the necessary data for the transaction.

6. **Sign Transaction Hash**: Signs the transaction hash using the root Safe account to authorize the transaction.

7. **Execute Transaction On Behalf**: Executes the transaction on behalf of the root Safe account using another EOA. An EOA sends a transaction to the Palmera Module contract to execute the `execTransactionOnBehalf` function, ensuring the transaction is successful.

8. **Verify Balances**: Verifies the balances of the last Safe account and the last EOA before and after the transaction to confirm the transaction executed correctly.

### Test Case 7 / 8: Create a Basic 1-to-3 Org in Palmera Module and Test ExecuteOnBehalf with Another Safe, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of a basic 1-to-3 organizational structure in the Palmera Module and the execution of a transaction on behalf of the root Safe by another Safe account. The test ensures that the Palmera Module's `execTransactionOnBehalf` function works as expected when the caller is another Safe account. This test verifies the interoperability and security of transactions within the hierarchical structure of the Palmera Module.

#### Steps

1. **Deploy Safe Accounts**: Deploys thirteen Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first thirteen Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic 1-to-3 organization in the Palmera Module with a specified name and retrieves the organization hash.

4. **Transfer ETH to Last Safe Account**: Transfers 0.153 ETH from the last account to the last Safe account, ensuring the last Safe account has a balance for the transaction.

5. **Get Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function, preparing the necessary data for the transaction.

6. **Sign Transaction Hash**: Signs the transaction hash using the root Safe account to authorize the transaction.

7. **Execute Transaction On Behalf**: Executes the transaction on behalf of the root Safe account using another Safe account. Another Safe account sends a transaction to the Palmera Module contract to execute the `execTransactionOnBehalf` function, ensuring the transaction is successful.

8. **Verify Balances**: Verifies the balances of the last Safe account and the last EOA before and after the transaction to confirm the transaction executed correctly.

### Test Case 9/10: Create 20 Basic Linear Orgs and Execute Arrays of Promises for Execution OnBehalf, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of 20 basic linear organizational structures in the Palmera Module and the execution of transactions on behalf of the root Safes by sending arrays of promises. The test ensures that the Palmera Module's `execTransactionOnBehalf` function can handle multiple simultaneous transactions and verifies that each transaction is executed correctly.

#### Steps

1. **Deploy Safe Accounts**: Deploys sixty-one Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first sixty Safe accounts from the deployed list and verifies the length of the slice.

3. **Create 20 Basic Linear Orgs**: Registers 20 basic linear organizations in the Palmera Module with specified names and retrieves the organization hashes for each.

4. **Prepare for Execute OnBehalf**:
    - For each organization, transfer 0.153 ETH from the last account to the last Safe account.
    - Retrieve the nonce and calculate the transaction hash for the `execTransactionOnBehalf` function for each organization.
    - Sign the transaction hash using the root Safe account to authorize the transaction.

5. **Execute Arrays of Promises**:
    - Create an array of promises for executing the `execTransactionOnBehalf` function for each organization.
    - Use another Safe account to execute the transactions in parallel.

6. **Verify Execution**:
    - Ensure that all transactions were executed successfully by checking the receipts.
    - Verify the balances of the last Safe accounts and the last EOA before and after the transactions to confirm the transactions executed correctly.

### Test Case 11/12: Create an Org with 13 Members, Promote the 1st Level Safe Account, and Test Execution OnBehalf on Both Leaves, Safe Version 1.4.1

#### Description

This test case aims to validate the creation of an organizational structure with 13 members in the Palmera Module, the promotion of a 1st level Safe account to a root Safe, and the execution of transactions on behalf of the new root Safe and the original root Safe over the last child Safe accounts. The test ensures that the Palmera Module's `execTransactionOnBehalf` function works as expected when the caller is an Externally Owned Account (EOA).

#### Steps

1. **Deploy Safe Accounts**: Deploys thirteen Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first thirteen Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic 1-to-3 organizational structure in the Palmera Module with a specified name and retrieves the organization hash.

4. **Promote 1st Level Safe Account**:
    - Retrieve the Safe ID of the 1st level Safe account.
    - Create and execute a transaction to promote the 1st level Safe account to a root Safe.
    - Verify that the Safe account is promoted and is the root of the organization over the 11th Safe account.

5. **Test Execution OnBehalf on First Leaf**:
    - Transfer 0.153 ETH from the last account to the last Safe account of the first leaf.
    - Retrieve the nonce and calculate the transaction hash for the `execTransactionOnBehalf` function.
    - Sign the transaction hash using the new root Safe account to authorize the transaction.
    - Execute the transaction on behalf of the new root Safe account using an EOA.
    - Verify the balances of the Safe account and the EOA before and after the transaction.

6. **Test Execution OnBehalf on Last Leaf**:
    - Transfer 0.153 ETH from the last account to the last Safe account of the last leaf.
    - Retrieve the nonce and calculate the transaction hash for the `execTransactionOnBehalf` function.
    - Sign the transaction hash using the original root Safe account to authorize the transaction.
    - Execute the transaction on behalf of the original root Safe account using an EOA.
    - Verify the balances of the Safe account and the EOA before and after the transaction.

### Test Case 13/14: Create an Org with 17 Members and Execute Arrays of 19 Promises of Multiple Kinds of Transactions, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of an organizational structure with 17 members in the Palmera Module and the execution of multiple kinds of transactions using an array of promises. The test ensures that the Palmera Module can handle multiple simultaneous transactions of different types and verifies that each transaction is executed correctly.

#### Steps

1. **Deploy Safe Accounts**: Deploys seventeen Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first seventeen Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic linear organizational structure in the Palmera Module with a specified name and retrieves the organization hash.

4. **Prepare and Execute Transactions**:
    - **Transfer ETH**: Transfers 0.153 ETH from the last account to the 5th level Safe account.
    - **Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function. Signs the transaction hash using the root Safe account.
    - **Create Safe Transactions**: Creates an array of 19 Safe transactions of different types, including adding owners, removing owners, setting roles, updating depth tree limits, and disconnecting Safes.
    - **Execute Transactions**: Executes all Safe transactions in parallel using an array of promises.

5. **Verify Execution**:
    - **Validate Transactions**: Ensures all transactions were executed successfully by checking the receipts.
    - **Check Balances**: Verifies the balances of the relevant Safe accounts and EOAs before and after the transactions.
    - **Check Organization Structure**: Verifies the organization structure and roles after the transactions, ensuring that owners are correctly added and removed, roles are set appropriately, and depth tree limits are updated.

### Test Case 15/16: Create an Org with 17 Members and Execute a Unique Safe Batch Transaction with Arrays of Multiple Kinds of Transactions, Safe Version 1.4.1 / 1.3.0

#### Description

This test case aims to validate the creation of an organizational structure with 17 members in the Palmera Module and the execution of multiple kinds of transactions using a unique Safe batch transaction. The test ensures that the Palmera Module can handle a complex batch of transactions and verifies that each transaction within the batch is executed correctly.

#### Steps

1. **Deploy Safe Accounts**: Deploys seventeen Safe accounts with the Palmera Module and Guard enabled. Initializes and deploys the Safe accounts with the specified version and sets up the Palmera Module and Guard for each account.

2. **Slice Safe Accounts**: Selects the first seventeen Safe accounts from the deployed list and verifies the length of the slice.

3. **Register Basic Org**: Registers a basic linear organizational structure in the Palmera Module with a specified name and retrieves the organization hash.

4. **Prepare Transactions**:
    - **Transfer ETH**: Transfers 0.153 ETH from the last account to the 5th level Safe account.
    - **Nonce and Transaction Hash**: Retrieves the nonce and calculates the transaction hash for the `execTransactionOnBehalf` function. Signs the transaction hash using the root Safe account.
    - **Create Transactions**: Creates an array of 19 transactions of different types, including adding owners, removing owners, setting roles, updating depth tree limits, and disconnecting Safes.

5. **Execute Batch Transaction**:
    - **Create Batch Transaction**: Combines the array of 19 transactions into a single Safe batch transaction.
    - **Execute Batch Transaction**: Executes the Safe batch transaction.

6. **Verify Execution**:
    - **Validate Batch Transaction**: Ensures the batch transaction was executed successfully by checking the receipt.
    - **Check Nonce**: Verifies that the nonce of the Palmera Module has incremented correctly after the batch transaction.
    - **Check Balances**: Verifies the balances of the relevant Safe accounts and EOAs before and after the batch transaction.
    - **Check Organization Structure**: Verifies the organization structure and roles after the batch transaction, ensuring that owners are correctly added and removed, roles are set appropriately, and depth tree limits are updated.
    - **Validate Individual Transactions**: Confirms that each individual transaction within the batch was executed correctly by checking specific conditions related to each transaction type.
