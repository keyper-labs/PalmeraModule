# Contract 

## Events

**Title:** Library Events

**Author:** general@palmeradao.xyz

### OrganisationCreated

```solidity
event OrganisationCreated(address creator, bytes32 org, string name)
```

_Event Fire when create a new Organisation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| creator | address | Address of the creator |
| org | bytes32 | Hash(on-chain Organisation) |
| name | string | String name of the organisation |

### SafeCreated

```solidity
event SafeCreated(bytes32 org, uint256 safeCreated, address lead, address creator, uint256 superSafe, string name)
```

_Event Fire when create a New Safe (Tier 0) into the organisation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| safeCreated | uint256 | ID of the safe |
| lead | address | Address of Safe Lead of the safe |
| creator | address | Address of the creator of the safe |
| superSafe | uint256 | ID of Superior Safe |
| name | string | String name of the safe |

### SafeRemoved

```solidity
event SafeRemoved(bytes32 org, uint256 safeRemoved, address lead, address remover, uint256 superSafe, string name)
```

_Event Fire when remove a Safe (Tier 0) from the organisation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| safeRemoved | uint256 | ID of the safe removed |
| lead | address | Address of Safe Lead of the safe |
| remover | address | Address of the creator of the safe |
| superSafe | uint256 | ID of Superior Safe |
| name | string | String name of the safe |

### SafeSuperUpdated

```solidity
event SafeSuperUpdated(bytes32 org, uint256 safeUpdated, address lead, address updater, uint256 oldSuperSafe, uint256 newSuperSafe)
```

_Event Fire when update SuperSafe of a Safe (Tier 0) from the organisation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| safeUpdated | uint256 | ID of the safe updated |
| lead | address | Address of Safe Lead of the safe |
| updater | address | Address of the updater of the safe |
| oldSuperSafe | uint256 | ID of old Super Safe |
| newSuperSafe | uint256 | ID of new Super Safe |

### TxOnBehalfExecuted

```solidity
event TxOnBehalfExecuted(bytes32 org, address executor, address superSafe, address target, bool result)
```

_Event Fire when Palmera Module execute a transaction on behalf of a Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| executor | address | Address of the executor |
| superSafe | address |  |
| target | address | Address of the Target Safe |
| result | bool | Result of the execution of transaction on behalf of the Safe (true or false) |

### ModuleEnabled

```solidity
event ModuleEnabled(address safe, address module)
```

_Event Fire when any Safe enable the Palmera Module_

### RootSafeCreated

```solidity
event RootSafeCreated(bytes32 org, uint256 newIdRootSafe, address creator, address newRootSafe, string name)
```

_Event Fire when any Root Safe create a new Root Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| newIdRootSafe | uint256 | New ID of the Root Safe |
| creator | address | Address of the creator |
| newRootSafe | address | Address of the new Root Safe |
| name | string | String name of the new Root Safe |

### RootSafePromoted

```solidity
event RootSafePromoted(bytes32 org, uint256 newIdRootSafe, address updater, address newRootSafe, string name)
```

_Event Fire when update SuperSafe of a Safe To Root Safe_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| newIdRootSafe | uint256 | ID of the safe updated |
| updater | address | Address of the updater of the safe |
| newRootSafe | address | Address of the new Root Safe |
| name | string | String name of the new Root Safe |

### WholeTreeRemoved

```solidity
event WholeTreeRemoved(bytes32 org, uint256 rootSafeId, address remover, string name)
```

_Event Fire when an Root Safe Remove Whole of Tree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| rootSafeId | uint256 | ID of the safe updated |
| remover | address | Address of the remover of the safe |
| name | string | String name of the new Root Safe |

### NewLimitLevel

```solidity
event NewLimitLevel(bytes32 org, uint256 rootSafeId, address updater, uint256 oldLimit, uint256 newLimit)
```

_Event Fire when any Root Safe change Depth Tree Limit_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| rootSafeId | uint256 | New ID of the Root Safe |
| updater | address | Address of the Root Safe |
| oldLimit | uint256 | uint256 Old Limit of Tree |
| newLimit | uint256 | uint256 New Limit of Tree |

### SafeDisconnected

```solidity
event SafeDisconnected(bytes32 org, uint256 safeId, address safe, address disconnector)
```

_Event Fire when remove a Safe (Tier 0) from the organisation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| org | bytes32 | Hash (On-chain Organisation) |
| safeId | uint256 | ID of the safe Disconnect |
| safe | address | Address of Safe Address of the safe Disconnect |
| disconnector | address | Address of the disconnector |

### AddedToList

```solidity
event AddedToList(address[] users)
```

_Event Fire when add several wallet into the deny/allow list_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| users | address[] | Array of wallets |

### DroppedFromList

```solidity
event DroppedFromList(address user)
```

_Event Fire when drop a wallet into the deny/allow list_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | Wallet to drop of the deny/allow list |

### PalmeraModuleSetup

```solidity
event PalmeraModuleSetup(address palmeraModule, address caller)
```

_Event when a new palmeraModule is setting up_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| palmeraModule | address | Address of the new palmeraModule |
| caller | address | Address of the deployer |

