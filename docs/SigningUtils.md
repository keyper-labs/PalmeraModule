# Contract 

## SigningUtils

**Title:** SigningUtils

**Author:** general@palmeradao.xyz

### Transaction

_Transaction structure_

```solidity
struct Transaction {
  address to;
  uint256 value;
  bytes data;
  enum Enum.Operation operation;
  uint256 safeTxGas;
  uint256 baseGas;
  uint256 gasPrice;
  address gasToken;
  address refundReceiver;
  bytes signatures;
}
```

