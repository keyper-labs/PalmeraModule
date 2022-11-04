# KeyperModule - Gnosis safe module for keyper

This contract is a registry of keyper organization/groups setup on a Safe that can be used by specific accounts. For this the contract needs to be enabled as a module on the Safe that holds the assets that should be transferred.

## Tech requirements

Copy .env.example as .env and fill it with your own API KEYS (alchemy, etherscan) & mnemonic to be used locally

Foundry is used as the development framework. Please install it following the instructions:
```
https://book.getfoundry.sh/getting-started/installation
```

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

* Deploy Keypermodule

Execute the command `deploy-module` located in the Makefile

* Deploy a new safe using our custom contracts (custom gnosis safe master copy & proxy factory)

Execute the command `deploy-new-safe` located in the Makefile

## Setting up a DAO
All the following calls have to be executed from a safe using safe execTransation function. Check documentation https://safe-docs.dev.gnosisdev.com/safe/docs/contracts_tx_execution/
# Register main organisation

```function registerOrg(string memory name)```

The address of the calling safe is going to be registered with the input name

# Add Subgroups to main organisation

```function addGroup(address org, address parent, string memory name)```

Need to specify to which organisation the new group will belong

## Requirements (not finalized)

Organization=Safe Root has multiple groups
Groups/Safe relationship
- Each group is associated to a safe
- Each group has a parent (parent has ownership over the group)
- Each group has set of child


Validate transfer rules - execTransactionFromModule:
- Safe signers can execute transactions if threshold met (normal safe verification)
- Safe group signers can execute transactions in behalf of any child safe
    - Group threshold kept

Setup groups rules:
- Root admin has full control over all groups (or over all groups that he is a designed admin?)
    => Remove/Add groups.
    => Remove/Add signers of any child safe
- Each group has a designed admin (full ownership of the safe)
- Can an admin be something different than a Safe contract?
