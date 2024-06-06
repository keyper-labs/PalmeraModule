# Contract 

## ICREATE3Factory

**Title:** Factory for deploying contracts to deterministic addresses via CREATE3

_its own namespace for deployed addresses._

**Enables deploying contracts using CREATE3. Each deployer (msg.sender) has**

### deploy

```solidity
function deploy(bytes32 salt, bytes creationCode) external payable returns (address deployed)
```

_The provided salt is hashed together with msg.sender to generate the final salt_

**Deploys a contract using CREATE3**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| salt | bytes32 | The deployer-specific salt for determining the deployed contract's address |
| creationCode | bytes | The creation code of the contract to deploy |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| deployed | address | The address of the deployed contract |

### getDeployed

```solidity
function getDeployed(address deployer, bytes32 salt) external view returns (address deployed)
```

_The provided salt is hashed together with the deployer address to generate the final salt_

**Predicts the address of a deployed contract**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| deployer | address | The deployer account that will call deploy() |
| salt | bytes32 | The deployer-specific salt for determining the deployed contract's address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| deployed | address | The address of the contract that will be deployed |

