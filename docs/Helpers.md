# Contract 

## Helpers

**Title:** Helpers

**Author:** general@palmeradao.xyz

_This contract is a helper contract for the Palmera Module_

### IsSafe

```solidity
modifier IsSafe(address safe)
```

_Modifier for Validate if the address is a Safe Smart Account Wallet_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | Address of the Safe Smart Account Wallet |

### domainSeparator

```solidity
function domainSeparator() public view returns (bytes32)
```

_Method to get the domain separator for Palmera Module_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | Hash of the domain separator |

### getChainId

```solidity
function getChainId() public view returns (uint256)
```

_Returns the chain id used by this contract._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The Chain ID |

### encodeTransactionData

```solidity
function encodeTransactionData(bytes32 org, address superSafe, address targetSafe, address to, uint256 value, bytes data, enum Enum.Operation operation, uint256 _nonce) public view returns (bytes)
```

_Method to get the Encoded Packed Data for Palmera Transaction_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| superSafe | address | address of the caller |
| targetSafe | address | address of the Safe |
| to | address | address of the receiver |
| value | uint256 | value of the transaction |
| data | bytes | data of the transaction |
| operation | enum Enum.Operation | operation of the transaction |
| _nonce | uint256 | nonce of the transaction |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | Hash of the encoded data |

### getTransactionHash

```solidity
function getTransactionHash(bytes32 org, address superSafe, address targetSafe, address to, uint256 value, bytes data, enum Enum.Operation operation, uint256 _nonce) external view returns (bytes32)
```

_Method to get the Hash Encoded Packed Data for Palmera Transaction_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| superSafe | address | address of the caller |
| targetSafe | address | address of the Safe |
| to | address | address of the receiver |
| value | uint256 | value of the transaction |
| data | bytes | data of the transaction |
| operation | enum Enum.Operation | operation of the transaction |
| _nonce | uint256 | nonce of the transaction |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | Hash of the encoded packed data |

### isSafe

```solidity
function isSafe(address safe) public view returns (bool)
```

_This method is used to validate if the address is a Safe Smart Account Wallet_

**Method to Validate if address is a Safe Smart Account Wallet**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | Address to validate |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### processAndSortSignatures

```solidity
function processAndSortSignatures(bytes32 dataHash, bytes signatures, address[] owners) internal pure returns (bytes)
```

_Method to get signatures order_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dataHash | bytes32 | Hash of the transaction data to sign |
| signatures | bytes | Signature of the transaction |
| owners | address[] | Array of owners of the  Safe Multisig Wallet |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | address of the Safe Proxy |

### getPreviewModule

```solidity
function getPreviewModule(address safe) internal view returns (address)
```

_Method to get Preview Module of the Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | address of the Safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | address of the Preview Module |

### _executeModuleTransaction

```solidity
function _executeModuleTransaction(address safe, bytes data) internal
```

_refactoring of execution of Tx with the privilege of the Module Palmera Labs, and avoid repeat code_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | Safe Address to execute Tx |
| data | bytes | Data to execute Tx |

