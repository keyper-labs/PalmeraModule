# Contract 

## PalmeraModule

**Title:** Palmera Module

**Author:** general@palmeradao.xyz

### NAME

```solidity
string NAME
```

_Definition of Safe Palmera Module_

**NAME Name of the Palmera Module**

### VERSION

```solidity
string VERSION
```

**VERSION Version of the Palmera Module**

### indexId

```solidity
uint256 indexId
```

_indexId of the safe_

### maxDepthTreeLimit

```solidity
uint256 maxDepthTreeLimit
```

_Max Depth Tree Limit_

### rolesAuthority

```solidity
address rolesAuthority
```

_RoleAuthority_

### indexSafe

```solidity
mapping(bytes32 => uint256[]) indexSafe
```

_Index of Safe
bytes32: Hash (On-chain Organisation) -> uint256: ID's Safes_

### depthTreeLimit

```solidity
mapping(bytes32 => uint256) depthTreeLimit
```

_Depth Tree Limit
bytes32: Hash (On-chain Organisation) -> uint256: Depth Tree Limit_

### nonce

```solidity
mapping(bytes32 => uint256) nonce
```

_Control Nonce of the Palmera Module per Org
bytes32: Hash (On-chain Organisation) -> uint256: Nonce by Orgt_

### safes

```solidity
mapping(bytes32 => mapping(uint256 => struct DataTypes.Safe)) safes
```

_Hash (On-chain Organisation) -> Safes
bytes32: Hash (On-chain Organisation).   uint256:SafeId of Safe Info_

### SafeIdRegistered

```solidity
modifier SafeIdRegistered(uint256 safe)
```

_Modifier for Validate if Org/Safe Exist or SuperSafeNotRegistered Not_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | uint256 | ID of the safe |

### SafeRegistered

```solidity
modifier SafeRegistered(address safe)
```

_Modifier for Validate if safe caller is Registered_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | Safe address |

### IsRootSafe

```solidity
modifier IsRootSafe(address safe)
```

_Modifier for Validate if the address is a Safe Smart Account Wallet and Root Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | Address of the Safe Smart Account Wallet |

### constructor

```solidity
constructor(address authorityAddress, uint256 maxDepthTreeLimitInitial) public
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

### execTransactionOnBehalf

```solidity
function execTransactionOnBehalf(bytes32 org, address superSafe, address targetSafe, address to, uint256 value, bytes data, enum Enum.Operation operation, bytes signatures) external payable returns (bool result)
```

**Calls execTransaction of the safe with custom checks on owners rights**

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

### addOwnerWithThreshold

```solidity
function addOwnerWithThreshold(address ownerAdded, uint256 threshold, address targetSafe, bytes32 org) external
```

_For instance addOwnerWithThreshold can be called by Safe Lead & Safe Lead modify only roles_

**This function will allow Safe Lead &amp; Safe Lead modify only roles
to to add owner and set a threshold without passing by normal multisig check**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ownerAdded | address | Address of the owner to be added |
| threshold | uint256 | Threshold of the Safe Multisig Wallet |
| targetSafe | address | Address of the Safe Multisig Wallet |
| org | bytes32 | Hash (On-chain Organisation) |

### removeOwner

```solidity
function removeOwner(address prevOwner, address ownerRemoved, uint256 threshold, address targetSafe, bytes32 org) external
```

_For instance of Remove Owner of Safe, the user lead/super/root can remove an owner without passing by normal multisig check signature_

**This function will allow User Lead/Super/Root to remove an owner**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| prevOwner | address | Address of the previous owner |
| ownerRemoved | address | Address of the owner to be removed |
| threshold | uint256 | Threshold of the Safe Multisig Wallet |
| targetSafe | address | Address of the Safe Multisig Wallet |
| org | bytes32 | Hash (On-chain Organisation) |

### setRole

```solidity
function setRole(enum DataTypes.Role role, address user, uint256 safeId, bool enabled) external
```

_Call must come from the root safe_

**Give user roles**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| role | enum DataTypes.Role | Role to be assigned |
| user | address | User that will have specific role (Can be EAO or safe) |
| safeId | uint256 | Safe Id which will have the user permissions on |
| enabled | bool | Enable or disable the role |

### registerOrg

```solidity
function registerOrg(string orgName) external returns (uint256 safeId)
```

_Call has to be done from a safe transaction_

**Register an organisation**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| orgName | string | String with of the org (This name will be hashed into smart contract) |

### createRootSafe

```solidity
function createRootSafe(address newRootSafe, string name) external returns (uint256 safeId)
```

_Call has to be done from a safe transaction_

**Call has to be done from another root safe to the organisation**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newRootSafe | address | Address of new Root Safe |
| name | string | string name of the safe |

### addSafe

```solidity
function addSafe(uint256 superSafeId, string name) external returns (uint256 safeId)
```

_Call coming from the safe_

**Add a safe to an organisation/safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| superSafeId | uint256 | Id of the superSafe |
| name | string | string name of the safe |

### removeSafe

```solidity
function removeSafe(uint256 safeId) public
```

_All actions will be driven based on the caller of the method, and args_

**Remove safe and reasign all child to the superSafe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | Id of the safe to be removed |

### disconnectSafe

```solidity
function disconnectSafe(uint256 safeId) external
```

_Disconnect Safe of a Org, Call must come from the root safe_

**Disconnect Safe of a Org**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | Id of the safe to be updated |

### removeWholeTree

```solidity
function removeWholeTree() external
```

_Remove whole tree of a RootSafe_

**Remove whole tree of a RootSafe**

### promoteRoot

```solidity
function promoteRoot(uint256 safeId) external
```

_Method to Promete a safe to Root Safe of an Org to Root Safe_

**Method to Promete a safe to Root Safe of an Org to Root Safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | Id of the safe to be updated |

### updateSuper

```solidity
function updateSuper(uint256 safeId, uint256 newSuperId) external
```

_Update the superSafe of a safe with a new superSafe, Call must come from the root safe_

**update superSafe of a safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | Id of the safe to be updated |
| newSuperId | uint256 | Id of the new superSafe |

### updateDepthTreeLimit

```solidity
function updateDepthTreeLimit(uint256 newLimit) external
```

_Method to update Depth Tree Limit_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newLimit | uint256 | new Depth Tree Limit |

### addToList

```solidity
function addToList(address[] users) external
```

_Funtion to Add Wallet to the List based on Approach of Safe Contract - Owner Manager_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| users | address[] | Array of Address of the Wallet to be added to the List |

### dropFromList

```solidity
function dropFromList(address user) external
```

_Function to Drop Wallet from the List  based on Approach of Safe Contract - Owner Manager_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | Array of Address of the Wallet to be dropped of the List |

### enableAllowlist

```solidity
function enableAllowlist() external
```

_Method to Enable Allowlist_

### enableDenylist

```solidity
function enableDenylist() external
```

_Method to Enable Allowlist_

### disableDenyHelper

```solidity
function disableDenyHelper() external
```

_Method to Disable All_

### getSafeInfo

```solidity
function getSafeInfo(uint256 safeId) external view returns (enum DataTypes.Tier, string, address, address, uint256[], uint256)
```

_Method for getting all info of a safe_

**Get all the information about a safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | uint256 of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | enum DataTypes.Tier | all the information about a safe |
| [1] | string |  |
| [2] | address |  |
| [3] | address |  |
| [4] | uint256[] |  |
| [5] | uint256 |  |

### hasNotPermissionOverTarget

```solidity
function hasNotPermissionOverTarget(address caller, bytes32 org, address targetSafe) public view returns (bool hasNotPermission)
```

**This function checks that caller has permission (as Root/Super/Lead safe) of the target safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| caller | address | Caller's address |
| org | bytes32 | Hash (On-chain Organisation) |
| targetSafe | address | Address of the target Safe Multisig Wallet |

### isOrgRegistered

```solidity
function isOrgRegistered(bytes32 org) public view returns (bool)
```

**check if the Organisation is registered**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### isRootSafeOf

```solidity
function isRootSafeOf(address root, uint256 safeId) public view returns (bool)
```

**Check if the address, is a rootSafe of the safe within an organisation**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| root | address | address of Root Safe of the safe |
| safeId | uint256 | ID's of the child safe/safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### isTreeMember

```solidity
function isTreeMember(uint256 superSafeId, uint256 safeId) public view returns (bool isMember)
```

**Check if the safe is a Is Tree Member of another safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| superSafeId | uint256 | ID's of the superSafe |
| safeId | uint256 | ID's of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| isMember | bool |  |

### isLimitLevel

```solidity
function isLimitLevel(uint256 superSafeId) public view returns (bool)
```

_Method to validate if is Depth Tree Limit_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| superSafeId | uint256 | ID's of Safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### isSuperSafe

```solidity
function isSuperSafe(uint256 superSafeId, uint256 safeId) public view returns (bool)
```

_Method to Validate is ID Safe a SuperSafe of a Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| superSafeId | uint256 | ID's of the Safe |
| safeId | uint256 | ID's of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### isPendingRemove

```solidity
function isPendingRemove(uint256 rootSafeId, uint256 safeId) public view returns (bool)
```

_Method to Validate is ID Safe is Pending to Disconnect (was Removed by SuperSafe)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rootSafeId | uint256 | ID's of Root Safe |
| safeId | uint256 | ID's of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

### isSafeRegistered

```solidity
function isSafeRegistered(address safe) public view returns (bool)
```

**Verify if the Safe is registered in any Org**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | address of the Safe |

### getRootSafe

```solidity
function getRootSafe(uint256 safeId) public view returns (uint256 rootSafeId)
```

_Method to get Root Safe of a Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | ID's of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| rootSafeId | uint256 | uint256 Root Safe Id's |

### getSafeAddress

```solidity
function getSafeAddress(uint256 safeId) external view returns (address)
```

_Method for getting the safe address of a safe_

**Get the safe address of a safe**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | uint256 of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | safe address |

### getOrgHashBySafe

```solidity
function getOrgHashBySafe(address safe) public view returns (bytes32)
```

_Method to get Org by Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safe | address | address of Safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | Org Hashed Name |

### getSafeIdBySafe

```solidity
function getSafeIdBySafe(bytes32 org, address safe) public view returns (uint256)
```

_Method to get Safe ID by safe address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | bytes32 hashed name of the Organisation |
| safe | address | Safe address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Safe ID |

### getOrgBySafe

```solidity
function getOrgBySafe(uint256 safeId) public view returns (bytes32 orgSafe)
```

_Method to get the hashed orgHash based on safe id_

**call to get the orgHash based on safe id**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | uint256 of the safe |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| orgSafe | bytes32 | Hash (On-chain Organisation) |

### isSafeLead

```solidity
function isSafeLead(uint256 safeId, address user) public view returns (bool)
```

**Check if a user is an safe lead of a safe/org**

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| safeId | uint256 | address of the safe |
| user | address | address of the user that is a lead or not |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool |

