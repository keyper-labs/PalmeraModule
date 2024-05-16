# PalmeraModule - Safe module for Palmera

This contract is a registry of keyper organization/squads setup on a Safe that can be used by specific accounts. For this the contract needs to be enabled as a module on the Safe that holds the assets that should be transferred.

## Tech requirements

Copy .env.example as .env and fill it with your own API KEYS (alchemy, etherscan) & mnemonic to be used locally

Foundry is used as the development framework. Please install it following the instructions:

```
https://book.getfoundry.sh/getting-started/installation
```

### Pre commit hooks

Follow instructions https://github.com/0xYYY/foundry-pre-commit

### Init submodules

The external smart contracts dependencies are place in the lib/ folder. In order to initialize them use this command:

```
git submodule update --init --recursive
```

### Compile contracts

```
forge build or make build
```

### Run tests

To run the tests using the local VM (anvil)

```
forge test or make test-gas-report
```

### Deploy contracts

-   Deploy Keypermodule

Execute the command `deploy-module` located in the Makefile

-   Deploy a new safe using our custom contracts (custom safe master copy & proxy factory)

Execute the command `deploy-new-safe` located in the Makefile

## Setting up a DAO

All the following calls have to be executed from a safe using safe execTransation function. Check documentation https://safe-docs.dev.gnosisdev.com/safe/docs/contracts_tx_execution/

# Register main organisation

`function registerOrg(string memory name)`

The address of the calling safe is going to be registered with the input name

# Add Subsquads to main organisation

`function addSquad(address org, address superSafe, string memory name)`

Need to specify to which organisation the new squad will belong

## Requirements (not finalized)

Organization=Safe Root has multiple squads
Squads/Safe relationship

-   Each squad is associated to a safe
-   Each squad has a superSafe (superSafe has ownership over the squad)
-   Each squad has set of child

Validate transfer rules - execTransactionFromModule:

-   Safe signers can execute transactions if threshold met (normal safe verification)
-   Safe squad signers can execute transactions in behalf of any child safe
    -   Squad threshold kept

Setup squads rules:

-   Root lead has full control over all squads (or over all squads that he is a designed lead?)
    => Remove/Add squads.
    => Remove/Add signers of any child safe
-   Each squad has a designed lead (full ownership of the safe)
-   Can an lead be something different than a Safe contract?
