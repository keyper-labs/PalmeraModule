# Contract 

## ValidAddress

**Title:** ValidAddress

_Helper contract to check if an address is valid_

### validAddress

```solidity
modifier validAddress(address to)
```

_Modifier for Valid if wallet is Zero Address or Not_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | Address to check |

## DenyHelper

**Title:** DenyHelper

**Author:** general@palmeradao.xyz

_RDeny Helper Palmera Modules_

**Deny Helpers Methods for the Palmera module**

### allowFeature

```solidity
mapping(bytes32 => bool) allowFeature
```

_Deny/Allowlist Flags by Org
Org ID ---> Flag_

### denyFeature

```solidity
mapping(bytes32 => bool) denyFeature
```

### listCount

```solidity
mapping(bytes32 => uint256) listCount
```

_Counters by Org
Org ID ---> Counter_

### listed

```solidity
mapping(bytes32 => mapping(address => address)) listed
```

_Mapping of Orgs to Wallets Deny or Allowed
Org ID ---> Mapping of Orgs to Wallets Deny or Allowed_

### Denied

```solidity
modifier Denied(bytes32 org, address wallet)
```

_Modifier for Valid if wallet is Denied/Allowed or Not_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) of the Org |
| wallet | address | Address to check if Denied/Allowed |

### isListed

```solidity
function isListed(bytes32 org, address wallet) public view returns (bool)
```

_Function to check if a wallet is Denied/Allowed_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) of the Org |
| wallet | address | Address to check the wallet is Listed |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the wallet is Listed |

### getPrevUser

```solidity
function getPrevUser(bytes32 org, address wallet) public view returns (address prevUser)
```

_Function to get the Previous User of the Wallet_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Address of Org where get the Previous User of the Wallet |
| wallet | address | Address of the Wallet |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| prevUser | address | Address of the Previous User of the Wallet |

