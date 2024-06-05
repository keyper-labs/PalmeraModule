# Contract 

## Errors

**Title:** Library DataTypes

**Author:** general@palmeradao.xyz

_Errors Palmera Modules_

**Error codes for the Palmera module**

### OrgNotRegistered

```solidity
error OrgNotRegistered(bytes32 org)
```

_Error messages when the Org Hash (On-chain Organisation) is not Registered_

### SafeIdNotRegistered

```solidity
error SafeIdNotRegistered(uint256 safe)
```

_Error messages when the Safe(`safe`) is not Registered_

### SuperSafeNotRegistered

```solidity
error SuperSafeNotRegistered(uint256 superSafe)
```

_Error messages when the Super Safe(`superSafe`) is not Registered_

### SafeNotRegistered

```solidity
error SafeNotRegistered(address safe)
```

_Error messages when the Safe(`safe`) is not Registered_

### NotAuthorizedAddOwnerWithThreshold

```solidity
error NotAuthorizedAddOwnerWithThreshold()
```

_Error messages when the Safe is not Autorized to Add Owner like Lead/Super/Root Safe_

### NotAuthorizedRemoveSafeFromOtherTree

```solidity
error NotAuthorizedRemoveSafeFromOtherTree()
```

_Error messages when the Safe is not Autorized to Remove Owner like Lead/Root Safe or Safe itself_

### NotAuthorizedRemoveSafeFromOtherOrg

```solidity
error NotAuthorizedRemoveSafeFromOtherOrg()
```

### NotAuthorizedRemoveOwner

```solidity
error NotAuthorizedRemoveOwner()
```

### NotAuthorizedExecOnBehalf

```solidity
error NotAuthorizedExecOnBehalf()
```

### NotAuthorizedUpdateSafeToOtherOrg

```solidity
error NotAuthorizedUpdateSafeToOtherOrg()
```

### NotPermittedReceiveEther

```solidity
error NotPermittedReceiveEther()
```

_Not Permitted to Receive Ether_

### CannotDisconnectedSafeBeforeRemoveChild

```solidity
error CannotDisconnectedSafeBeforeRemoveChild(uint256 children)
```

_Error messages when try to disconnect Safe before remove it, and show the Safe's children Safe Id's_

### CannotRemoveSafeBeforeRemoveChild

```solidity
error CannotRemoveSafeBeforeRemoveChild(uint256 children)
```

_Error messages when try to remove Safe before remove it's children, and show the Safe's children Safe Id's_

### CannotDisablePalmeraModule

```solidity
error CannotDisablePalmeraModule(address module)
```

### CannotDisablePalmeraGuard

```solidity
error CannotDisablePalmeraGuard(address guard)
```

### SafeAlreadyRemoved

```solidity
error SafeAlreadyRemoved()
```

### NotAuthorizedAsNotSafeLead

```solidity
error NotAuthorizedAsNotSafeLead()
```

_Error messages when the Caller is not Autorized to execute any action like Lead Safe_

### NotAuthorizedAsNotRootOrSuperSafe

```solidity
error NotAuthorizedAsNotRootOrSuperSafe()
```

_Error messages when the Caller is not Autorized to execute any action like Super Safe_

### NotAuthorizedUpdateNonChildrenSafe

```solidity
error NotAuthorizedUpdateNonChildrenSafe()
```

_Error messages when the Root Safe is not Autorized Update Super Safe for a Safe in Another Tree_

### NotAuthorizedUpdateNonSuperSafe

```solidity
error NotAuthorizedUpdateNonSuperSafe()
```

### NotAuthorizedDisconnectChildrenSafe

```solidity
error NotAuthorizedDisconnectChildrenSafe()
```

_Error messages when the Root Safe is not Autorized to Disconnect an Safe in Another Tree_

### NotAuthorizedSetRoleAnotherTree

```solidity
error NotAuthorizedSetRoleAnotherTree()
```

_Error messages when the Root Safe is not Autorized to Update a Role in a Safe in Another Tree_

### OwnerNotFound

```solidity
error OwnerNotFound()
```

_Error messages the Owner is not Found into the Safe Owners_

### OwnerAlreadyExists

```solidity
error OwnerAlreadyExists()
```

_Error messages the Owner Already Exist into the Safe Owners_

### CreateSafeProxyFailed

```solidity
error CreateSafeProxyFailed()
```

_Error messages when Fail try to create a new Safe with the Palmera Module Enabled_

### InvalidThreshold

```solidity
error InvalidThreshold()
```

_Error messages when Invalid Threshold is provided_

### TxExecutionModuleFailed

```solidity
error TxExecutionModuleFailed()
```

_Error messages when Try to Execute a Transaction On Behalf and Fail_

### PreviewModuleNotFound

```solidity
error PreviewModuleNotFound(address safe)
```

### TxOnBehalfExecutedFailed

```solidity
error TxOnBehalfExecutedFailed()
```

_Error messages when Try to Execute a Transaction On Behalf and Fail_

### InvalidSafe

```solidity
error InvalidSafe(address safe)
```

_Error messages when the caller is an Invalid Safe_

### InvalidRootSafe

```solidity
error InvalidRootSafe(address safe)
```

_Error messages when the caller is an Invalid Root Safe_

### InvalidSafeId

```solidity
error InvalidSafeId()
```

_Error messages when the Safe is an Invalid ID's_

### SetRoleForbidden

```solidity
error SetRoleForbidden(enum DataTypes.Role role)
```

_Error messages when the Try to Modify a Role Not Permitted_

### OrgAlreadyRegistered

```solidity
error OrgAlreadyRegistered(bytes32 safe)
```

_Error messages when Org Already Registered_

### SafeAlreadyRegistered

```solidity
error SafeAlreadyRegistered(address safe)
```

_Error messages when Safe Already Registered_

### EmptyName

```solidity
error EmptyName()
```

_Error messages when the String Name is Empty_

### TreeDepthLimitReached

```solidity
error TreeDepthLimitReached(uint256 limit)
```

_Errors messages when Raised the Level Limit_

### InvalidLimit

```solidity
error InvalidLimit()
```

_Errors messages when New Limit is more than Max Limit or less than or Equal to actual value_

### ZeroAddressProvided

```solidity
error ZeroAddressProvided()
```

_Errors Module DenyHelpers
Error messages when the Address is a Zero Address_

### InvalidAddressProvided

```solidity
error InvalidAddressProvided()
```

_Error messages when the Address is Invalid Address_

### UserAlreadyOnList

```solidity
error UserAlreadyOnList()
```

_Error messages when the Address is Already on the List_

### AddresNotAllowed

```solidity
error AddresNotAllowed()
```

_Error messages when the Address is Not Allowed_

### AddressDenied

```solidity
error AddressDenied()
```

_Error messages when the Address is Denied_

### DenyHelpersDisabled

```solidity
error DenyHelpersDisabled()
```

_Error messages when the Deny Helper is Disabled_

### ListEmpty

```solidity
error ListEmpty()
```

_Error messages when the List of Allow/Deny is Empty_

