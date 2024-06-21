# PalmeraModule - Safe module for Palmera

[Overview](./doc/General%20Overview.md)

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

### Compile contracts foundry

```
forge build or make build
```

### Run tests foundry

[Tests foundry docs](./doc/Foundry%20Unit-Test%20Overview.md)

To run the tests using the local VM (anvil)

```
forge test
```

### Run tests hardhat

[Tests hardat docs](./doc/Hardhat%20Unit-Test%20Overview.md)

To run the tests using the local VM (hardhat)

```
yarn run test
```
