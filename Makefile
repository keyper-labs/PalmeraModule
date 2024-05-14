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
build:; forge clean && forge build

build-size-report :; forge clean && forge build --sizes

# chmod scripts
scripts :; chmod +x ./scripts/*

# Tests
test :; forge test -vvv --no-match-contract='Skip*'

coverage :; forge coverage -vvv --no-match-contract='Skip*'

test-gas-report :; forge test --gas-report -vvv

# Forge Formatter
check :; forge fmt --check
format :; forge fmt

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot --no-match-contract='Skip*'

# Rename all instances of femplate with the new repo name
rename :; chmod +x ./scripts/* && ./scripts/rename.sh

# Generate typescript bindings
ts-binding :; npx typechain --target ethers-v5 --out-dir out/types/ './out/**/*.json'

# Deploy module in Polygon
deploy-keyper-env-polygon :; source .env && forge script script/DeployKeyperEnv.s.sol:DeployKeyperEnv --rpc-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --skip-simulation --broadcast --verify --etherscan-api-key ${POLYGONSCAN_KEY} -vvvv --with-gas-price 120000000000 

# Deploy module
deploy-keyper-env :; source .env && forge script script/DeployKeyperEnv.s.sol:DeployKeyperEnv --rpc-url ${SEPOLIA_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_KEY} -vvvv

# Deploy module in fork-polygon
deploy-keyper-env-fork-polygon :; source .env && forge script script/DeployKeyperEnv.s.sol:DeployKeyperEnv --fork-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY}

# Deploy New Safe
deploy-new-safe :; source .env && forge script script/DeployKeyperSafe.t.sol:DeployKeyperSafe --rpc-url ${GOERLI_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv
 
# Run Unit-Test in Fork polygon
test-fork-polygon :; source .env && forge script script/SkipExecutionOnBehalf.s.sol:SkipSeveralScenarios --fork-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv