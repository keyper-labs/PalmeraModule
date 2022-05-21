# KeyperModule - Gnosis safe module for keyper

This contract is a registry of keyper organization/groups setup on a Safe that can be used by specific accounts. For this the contract needs to be enabled as a module on the Safe that holds the assets that should be transferred.
## Setting up groups

The contract is designed as a single point registry. This way not every Safe needs to deploy their own module and it is possible that this module is shared between different Safes.

To create a root organization for a Safe it is first required that the safe creates a "root" **org**. For this a Safe transaction needs to be executed that calls `createRootOrg`. This method will add the root **org** for `msg.sender`, which is the Safe in case of a Safe transaction. The `createRootORg` method can be called multiple times with the same address for a root **org** without failure.

Once a root **org** has been enabled it is possible to add groups. For this root group (admin) needs to execute the calls `addGroup`.

## Requirements

Organization=Safe Root has multiple groups

Validate transfer rules - execTransactionFromModule:
- Safe signers can execute transactions if threshold met (normal safe verification)
- Safe group signers can execute transactions in behalf of any child safe
    - Group threshold kept 
    - Should be able to mix signers auth? yes

Setup groups rules:
- Root admin has full control over all groups (or over all groups that he is a designed admin?)
    => Remove/Add groups.
    => Remove/Add signers of any child safe
- Each group has a designed admin (full ownership of the safe)
- Can an admin be something different than a Safe contract?

Groups/Safe relationship
- Each group is associated to a safe
- Each group has a parent (parent has ownership over the group)
- Each group has set of childs


## Data structure
// TODO: analyze if this storage optimal
organizations map Orgs -> Set of groups
map (address -> map (address -> group))


Group:
- name
- safe address
- list of child groups
- admin
- parent


Full set of signers for the group
// Safe -> All signers associated to the safe/group
full_signers map (address -> map -> (address -> bool))

## Keyper module functions

High level Safe needs to execute the following functions 
createRootOrg(...)
addGroup(...)
addChildGroup(...)
removeGroup(...)
