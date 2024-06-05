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
### _hashTypedDataV4

```solidity
function _hashTypedDataV4(bytes32 domainSeparator, bytes32 structHash) internal view virtual returns (bytes32)
```

_Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
function returns the hash of the fully encoded EIP712 message for this domain.

This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:

```solidity
bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
    keccak256("Mail(address to,string contents)"),
    mailTo,
    keccak256(bytes(mailContents))
)));
address signer = ECDSA.recover(digest, signature);
```_

### createDigestExecTx

```solidity
function createDigestExecTx(bytes32 domainSeparatorSafe, struct SigningUtils.Transaction safeTx) public view returns (bytes32)
```

_Given a transaction, it creates a hash of the transaction that can be signed_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| domainSeparatorSafe | bytes32 | Hash of the Safe domain separator |
| safeTx | struct SigningUtils.Transaction | Safe transaction |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | Hash of the transaction |

