# Contract 

## ISafe

**Title:** Safe Interface

**Author:** general@palmeradao.xyz

### execTransactionFromModule

```solidity
function execTransactionFromModule(address to, uint256 value, bytes data, enum Enum.Operation operation) external returns (bool success)
```

### execTransaction

```solidity
function execTransaction(address to, uint256 value, bytes data, enum Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address payable refundReceiver, bytes signatures) external payable returns (bool success)
```

### addOwnerWithThreshold

```solidity
function addOwnerWithThreshold(address owner, uint256 _threshold) external
```

### removeOwner

```solidity
function removeOwner(address prevOwner, address owner, uint256 _threshold) external
```

### getOwners

```solidity
function getOwners() external view returns (address[])
```

### isOwner

```solidity
function isOwner(address owner) external view returns (bool)
```

### getThreshold

```solidity
function getThreshold() external view returns (uint256)
```

### isModuleEnabled

```solidity
function isModuleEnabled(address module) external view returns (bool)
```

### disableModule

```solidity
function disableModule(address prevModule, address module) external
```

### setGuard

```solidity
function setGuard(address guard) external
```

### getModulesPaginated

```solidity
function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] array, address next)
```

### checkSignatures

```solidity
function checkSignatures(bytes32 dataHash, bytes data, bytes signatures) external view
```

## ISafeProxy

**Title:** Safe Proxy Interface

**Author:** general@palmeradao.xyz

### createProxy

```solidity
function createProxy(address singleton, bytes data) external returns (address proxy)
```

_Allows to create new proxy contact and execute a message call to the new proxy within one transaction._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| singleton | address | Address of singleton contract. |
| data | bytes | Payload for message call sent to new proxy contract. |

### createProxyWithNonce

```solidity
function createProxyWithNonce(address _singleton, bytes initializer, uint256 saltNonce) external returns (address proxy)
```

_Allows to create new proxy contact and execute a message call to the new proxy within one transaction._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _singleton | address | Address of singleton contract. |
| initializer | bytes | Payload for message call sent to new proxy contract. |
| saltNonce | uint256 | Nonce that will be used to generate the salt to calculate the address of the new proxy contract. |

