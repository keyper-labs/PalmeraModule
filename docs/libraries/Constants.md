# Contract 

## Constants

**Title:** Library Constants

**Author:** general@palmeradao.xyz

**Constants Definitions for the Palmera module**

### SENTINEL_ADDRESS

```solidity
address SENTINEL_ADDRESS
```

_Sentinel Owners for Safe_

### DOMAIN_SEPARATOR_TYPEHASH

```solidity
bytes32 DOMAIN_SEPARATOR_TYPEHASH
```

_keccak256(
    "EIP712Domain(uint256 chainId,address verifyingContract)"
);_

### PALMERA_TX_TYPEHASH

```solidity
bytes32 PALMERA_TX_TYPEHASH
```

_keccak256(
    "PalmeraTx(address org,address superSafe,address targetSafe,address to,uint256 value,bytes data,uint8 operation,uint256 _nonce)"
);_

### FALLBACK_HANDLER

```solidity
address FALLBACK_HANDLER
```

### ADD_OWNER

```solidity
bytes4 ADD_OWNER
```

_Signature for Roles and Permissions Management of Add Owner_

### REMOVE_OWNER

```solidity
bytes4 REMOVE_OWNER
```

_Signature for Roles and Permissions Management of Remove Owner_

### ROLE_ASSIGMENT

```solidity
bytes4 ROLE_ASSIGMENT
```

_Signature for Roles and Permissions Management of Role Assigment_

### CREATE_ROOT_SAFE

```solidity
bytes4 CREATE_ROOT_SAFE
```

_Signature for Roles and Permissions Management of Create Root Safe_

### ENABLE_ALLOWLIST

```solidity
bytes4 ENABLE_ALLOWLIST
```

_Signature for Roles and Permissions Management of Enable Allowlist_

### ENABLE_DENYLIST

```solidity
bytes4 ENABLE_DENYLIST
```

_Signature for Roles and Permissions Management of Enable Denylist_

### DISABLE_DENY_HELPER

```solidity
bytes4 DISABLE_DENY_HELPER
```

_Signature for Roles and Permissions Management of Disable Deny Helper_

### ADD_TO_LIST

```solidity
bytes4 ADD_TO_LIST
```

_Signature for Roles and Permissions Management of Add to List_

### DROP_FROM_LIST

```solidity
bytes4 DROP_FROM_LIST
```

_Signature for Roles and Permissions Management of Drop from List_

### UPDATE_SUPER_SAFE

```solidity
bytes4 UPDATE_SUPER_SAFE
```

_Signature for Roles and Permissions Management of Update Super Safe_

### PROMOTE_ROOT

```solidity
bytes4 PROMOTE_ROOT
```

_Signature for Roles and Permissions Management of Promote Root Safe_

### UPDATE_DEPTH_TREE_LIMIT

```solidity
bytes4 UPDATE_DEPTH_TREE_LIMIT
```

_Signature for Roles and Permissions Management of Update Depth Tree Limit_

### EXEC_ON_BEHALF

```solidity
bytes4 EXEC_ON_BEHALF
```

_Signature for Roles and Permissions Management of Execution on Behalf_

### REMOVE_SAFE

```solidity
bytes4 REMOVE_SAFE
```

_Signature for Roles and Permissions Management of Remove Safe_

### REMOVE_WHOLE_TREE

```solidity
bytes4 REMOVE_WHOLE_TREE
```

_Signature for Roles and Permissions Management of Remove Whole Tree_

### DISCONNECT_SAFE

```solidity
bytes4 DISCONNECT_SAFE
```

_Signature for Roles and Permissions Management of Disconnect Safe_

### GUARD_STORAGE_SLOT

```solidity
bytes32 GUARD_STORAGE_SLOT
```

_keccak256("guard_manager.guard.address")_

### EIP1271_MAGIC_VALUE

```solidity
bytes4 EIP1271_MAGIC_VALUE
```

_bytes4(keccak256("isValidSignature(bytes,bytes)")_

