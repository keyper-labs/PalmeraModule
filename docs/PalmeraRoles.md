# Contract 

## PalmeraRoles

**Title:** Palmera Roles

**Author:** general@palmeradao.xyz

### NAME

```solidity
string NAME
```

**Name of the Palmera Roles**

### VERSION

```solidity
string VERSION
```

**Version of the Palmera Roles**

### constructor

```solidity
constructor(address palmeraModule) public
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

### setupRoles

```solidity
function setupRoles(address palmeraModule) internal
```

**Configure roles access control on Authority**

### setUserRole

```solidity
function setUserRole(address user, uint8 role, bool enabled) public virtual
```

**function to assign a role to a user**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | address of the user |
| role | uint8 | uint8 role to assign |
| enabled | bool | bool enable or disable the role |

