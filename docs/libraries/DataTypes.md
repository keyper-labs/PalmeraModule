# Contract 

## DataTypes

**Title:** Library DataTypes

**Author:** general@palmeradao.xyz

_Definition of the Data Types for the Palmera Module_

**Data Types for the Palmera module**

### Role

_typos of Roles into Palmera Modules_

```solidity
enum Role {
  SAFE_LEAD,
  SAFE_LEAD_EXEC_ON_BEHALF_ONLY,
  SAFE_LEAD_MODIFY_OWNERS_ONLY,
  SUPER_SAFE,
  ROOT_SAFE
}
```
### Tier

_typos of safes into Palmera Modules_

```solidity
enum Tier {
  SAFE,
  ROOT,
  REMOVED
}
```
### Safe

_Struct for Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |

```solidity
struct Safe {
  enum DataTypes.Tier tier;
  string name;
  address lead;
  address safe;
  uint256[] child;
  uint256 superSafe;
}
```

