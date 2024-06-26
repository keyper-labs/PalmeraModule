# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean install update build

# Clean the repo
clean :; forge clean

# Install the Modules
install :; forge install

# Update Dependencies
update:; forge update

# Builds
build:; forge clean && forge fmt && forge build

build-size-report :; forge clean && forge fmt && forge build --sizes

# chmod scripts
scripts :; chmod +x ./scripts/*

# Tests
test :; forge fmt && forge test -vvv --no-match-contract='Skip*'

coverage :; forge coverage -vvv --no-match-contract='Skip*'

test-gas-report : build-size-report ; forge fmt && forge test --gas-report -vvv

# Forge Formatter
check :; forge fmt --check
format :; forge fmt

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot --no-match-contract='Skip*'

# Rename all instances of femplate with the new repo name
rename :; chmod +x ./scripts/* && ./scripts/rename.sh

# Generate typescript bindings
ts-binding :; npx typechain --target ethers-v5 --out-dir out/types/ './out/**/*.json'

# Deploy Libraries
deploy-palmera-libraries :; source .env && forge script script/DeployLibraries.s.sol:DeployLibraries --rpc-url ${SEPOLIA_RPC_URL}  --private-key ${PRIVATE_KEY} --skip-simulation --broadcast --verify --etherscan-api-key ${ETHERSCAN_KEY} -vvvv

# Deploy Libraries
deploy-palmera-libraries-polygon :; source .env && forge script script/DeployLibraries.s.sol:DeployLibraries --rpc-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --skip-simulation --broadcast --verify --etherscan-api-key ${POLYGONSCAN_KEY} -vvvv

# Deploy module in Polygon
deploy-palmera-env-polygon :; source .env && forge script script/DeployPalmeraEnv.s.sol:DeployPalmeraEnv --rpc-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --skip-simulation --broadcast --verify --etherscan-api-key ${POLYGONSCAN_KEY} -vvvv

# Deploy module
deploy-palmera-env :; source .env && forge script script/DeployPalmeraEnv.s.sol:DeployPalmeraEnv --rpc-url ${SEPOLIA_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_KEY} -vvvv

# Deploy module in fork-polygon
deploy-palmera-env-fork-polygon :; source .env && forge script script/DeployPalmeraEnv.s.sol:DeployPalmeraEnv --fork-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY}

# Deploy New Safe
deploy-new-safe :; source .env && forge script script/DeployPalmeraSafe.t.sol:DeployPalmeraSafe --rpc-url ${GOERLI_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv
 
# Run Unit-Test in Fork polygon
test-fork-polygon :; source .env && forge script script/SkipExecutionOnBehalf.s.sol:SkipSeveralScenarios --fork-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv