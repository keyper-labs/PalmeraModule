# Contract 

## Attacker

**Title:** Attacker

**Author:** general@palmeradao.xyz

### orgFromAttacker

```solidity
bytes32 orgFromAttacker
```

**Hash On-chain Organisation to Attack**

### superSafeFromAttacker

```solidity
address superSafeFromAttacker
```

**Safe super address to Attack**

### targetSafeFromAttacker

```solidity
address targetSafeFromAttacker
```

**Safe target address to Attack**

### dataFromAttacker

```solidity
bytes dataFromAttacker
```

**Data payload of the transaction to Attack**

### signaturesFromAttacker

```solidity
bytes signaturesFromAttacker
```

**Packed signatures data (v, r, s) to Attack**

### owners

```solidity
address[] owners
```

**Owners of the Safe Multisig Wallet Attacker**

### palmeraModule

```solidity
contract PalmeraModule palmeraModule
```

**Instance of PalmeraModule**

### constructor

```solidity
constructor(address payable _contractToAttackAddress) public
```

### receive

```solidity
receive() external payable
```

### performAttack

```solidity
function performAttack(bytes32 org, address superSafe, address targetSafe, address to, uint256 value, bytes data, enum Enum.Operation operation, bytes signatures) external returns (bool result)
```

**Function to perform the attack on the target contract, through the execTransactionOnBehalf**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | ID's Organisation |
| superSafe | address | Safe super address |
| targetSafe | address | Safe target address |
| to | address | Address to which the transaction is being sent |
| value | uint256 | Value (ETH) that is being sent with the transaction |
| data | bytes | Data payload of the transaction |
| operation | enum Enum.Operation | kind of operation (call or delegatecall) |
| signatures | bytes | Packed signatures data (v, r, s) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | true if transaction was successful. |

### setOwners

```solidity
function setOwners(address[] _owners) public
```

**function to set the owners of the Safe Smart Account Wallet**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _owners | address[] | Array of owners of the Safe Smart Account Wallet |

### getBalanceFromSafe

```solidity
function getBalanceFromSafe(address _safe) external view returns (uint256)
```

**function to get the balance of the Safe Smart Account Wallet**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _safe | address | Address of the Safe Smart Account Wallet |

### getBalanceFromAttacker

```solidity
function getBalanceFromAttacker() external view returns (uint256)
```

**function to get the balance of the attacker contract**

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | balance of the attacker contract |

### getOwners

```solidity
function getOwners() public view returns (address[])
```

**function to get the owners of the Safe Multisig Wallet**

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address[] | Array of owners of the Safe Multisig Wallet |

### getThreshold

```solidity
function getThreshold() public pure returns (uint256)
```

**function to get the threshold of the Safe Smart Account Wallet**

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | threshold of the Safe Smart Account Wallet |

### setParamsForAttack

```solidity
function setParamsForAttack(bytes32 _org, address _superSafe, address _targetSafe, bytes _data, bytes _signatures) internal
```

**function to set the parameters for the attack**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _org | bytes32 | ID's Organisation |
| _superSafe | address | Safe super address |
| _targetSafe | address | Safe target address |
| _data | bytes | Data payload of the transaction |
| _signatures | bytes | Packed signatures data (v, r, s) |

