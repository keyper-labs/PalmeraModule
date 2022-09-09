# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean install update build

# Install proper solc version.
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_8_13

# Clean the repo
clean  :; forge clean

# Install the Modules
install :; forge install

# Update Dependencies
update:; forge update

# Builds
build  :; forge build

# chmod scripts
scripts :; chmod +x ./scripts/*

# Tests
test :; forge clean && forge test --optimize --optimizer-runs 1000000 -v # --ffi # enable if you need the `ffi` cheat code on HEVM

# Lints
lint :; prettier --write src/**/*.sol && prettier --write src/*.sol

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot

# Rename all instances of femplate with the new repo name
rename :; chmod +x ./scripts/* && ./scripts/rename.sh

# Generate typescript bindings
ts-binding :; npx typechain --target ethers-v5 --out-dir out/types/ './out/**/*.json'

# Deploy module
deploy-module :; source .env && forge script script/DeployModule.t.sol:DeployModule --rpc-url ${GOERLI_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_KEY} -vvvv

deploy-new-safe :; source .env && forge script script/DeployKeyperSafe.t.sol:DeployKeyperSafe --rpc-url ${GOERLI_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv