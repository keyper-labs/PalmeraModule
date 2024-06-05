# Contract 

## PalmeraGuard

**Title:** Palmera Guard

**Author:** general@palmeradao.xyz

### palmeraModule

```solidity
contract PalmeraModule palmeraModule
```

### NAME

```solidity
string NAME
```

**Name of the Guard**

### VERSION

```solidity
string VERSION
```

**Version of the Guard**

### constructor

```solidity
constructor(address payable palmeraModuleAddr) public
```

### fallback

```solidity
fallback() external
```

**Fallback function: called when someone sends ETH or calls a function that does not exist**

### receive

```solidity
receive() external payable
```

**Receive function: called when someone sends ETH to the contract without data**

### checkTransaction

```solidity
function checkTransaction(address, uint256, bytes, enum Enum.Operation, uint256, uint256, uint256, address, address payable, bytes, address) external
```

**Instance of Base Guard Safe Interface**

### checkAfterExecution

```solidity
function checkAfterExecution(bytes32, bool) external view
```

_Check if the transaction is allowed, based of have the rights to execute it._

**Instance of Base Guard Safe Interface**

