# Palmera Module Principal of Diagramas - Technical Specification

## Table of Contents

- Project Overview
- Functional Requirements
  - 1.1. Enable Module and Guard
  - 1.2. Roles and Authorizations
  - 1.3. Features
    - Register a New On-Chain Organization
    - Add a New Safe
    - Add New Roles
    - Add a New Root Safe
    - Remove a Safe
    - Disconnect a Safe
    - Execute a Transaction on Behalf Of

## Project Overview

The Palmera Module is an orchestration framework for On-Chain Organizations based on the Safe ecosystem, enabling the creation and management of hierarchies and permissions within On-Chain Organizations. It extends the capabilities of Safe’s multisig wallet to manage assets and treasury in a secure and hierarchical manner. More Details in [Palmera Module Docs](https://docs.palmeradao.xyz/palmera).

## Functional Requirements

### 1.1. Enable Module and Guard

if you wanna to see in details the process to Enable Module and Set Guard, follow the docs and diagrams in:

- To Enable Module: [Safe Modules](https://docs.safe.global/advanced/smart-account-modules)
- Set Guard: [Safe Guard](https://docs.safe.global/advanced/smart-account-guards)

### 1.2. Roles and Authorizations

In this point we see the initial setup between Palmera Roles and Palmera Module, for Setup the Roles using the Solmete Auth / Roles Library, and the next steps to Deploy all Palmera Module and Guard.

```mermaid
sequenceDiagram
    actor D as Deployer
    participant C as CREATE3 Factory (Deployed)
    participant R as Palmera Roles
    participant M as Palmera Module
    participant G as Palmera Guard

    D->>+C: Request the Next Address to Deploy with Salt Random
    C-->>D: Get Palmera Module Address Predicted
    D->>+R: Deploy Palmera Roles with
    opt Setup of Roles and Authorizations
        R->>+M: Setup Palmera Module like Admin of Roles
        Note over R, M: Setup Roles and Authorizations for Palmera Module <br> like are defined into Palmera Roles, where the Admin <br> is the Palmera Module and the unique can change <br> the Roles and Authorizations
    end
    R-->>D: Get Palmera Roles Deployed
    D->>+C: Deploy Palmera Module through CREATE3 Factory with Salt and Bytecode
    C->>D: Get Palmera Module Deployed
    D->>+M: Verify Palmera Module was Deployed Correctelly
    M-->>D: Palmera Module Deployed
    D->>+G: Deploy Palmera Guard with Palmera Moduled Address Deployed
    G-->>D: Get Palmera Guard Deployed
```

### 1.3. Features

- **Hierarchical Management**: Palmera Module allows the creation of hierarchical structures within the organization, enabling the creation of sub-organizations and the management of permissions and assets in a hierarchical manner.

- **Permission Management**: Palmera Module allows the management of permissions within the organization, enabling the creation of roles and authorizations for each role.

- **Asset Management**: Palmera Module allows the management of assets within the organization, enabling the creation of treasury and the management of assets in a secure manner.

- **Governance Management**: Palmera Module allows the management of governance within the organization, enabling the creation of voting mechanisms and the management of proposals in a secure manner.

#### Register a New On-Chain Organization

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (regiterOrg) to Palmera Module
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (regiterOrg) to Palmera Module
    S->>PM: Execute the Transaction
    opt Organization Register Process
        PM-->>+PM: Validate the Organization Name is Unique
        PM-->>+PM: Validate the Safe Proxy is not Registered
        PM-->>+O: Register the Organization
        PM-->>+O: Set Safe Proxy like Root Safe of Organization
    end
    PM->>OW: Get Organization Hash Registered
```

#### Add a New Safe

Function: addSafe()
Description: Adds a new root safe. Only an existing root safe can add another root safe.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+PM: Verify the Organization Hash is Registered
    PM-->>OW: Organization Hash is Registered
    OW->>+PM: Request RootSafe Id from Organization
    PM-->>OW: Get RootSafe Id
    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (addSafe) to <br> Palmera Module to add a new Safe Proxy <br> to Organization with RootSafe Id
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Sign the Transaction
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (addSafe) to <br> Palmera Module to add a new Safe Proxy <br> to Organization with RootSafe Id
    S->>PM: Execute the Transaction
    opt Add New Safe Process
        PM-->>+PM: Validate the RootSafe Id is Registered
        PM-->>+PM: Validate the Safe Proxy is not Registered
        PM-->>+PM: Validate the Safe Proxy is not Registered
        PM-->>+O: Add the Safe Proxy
        Note over PM, O: The Safe Proxy is added to the <br> Organization under the Root Safe, <br> and the Safe Proxy is assigned an <br> unique Safe Id into the Organization
    end
    PM->>OW: Get Safe Id into Organization
```

#### Add New Roles

Function: setRole()
Description: Assigns a new role to a user. This must be called by the root safe.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (setRole) to Palmera Module
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (setRole) to Palmera Module
    S->>PM: Execute the Transaction
    opt Role Register Process
        PM-->>+PM: Validate the Caller have Role to Assign Roles To User
        PM-->>+PM: Validate the Safe Id is Registered
        PM-->>+O: Setup the Role
    end
    PM->>OW: Get Role Hash Registered
```

#### Add a New Root Safe

Function: createRootSafe()
Description: A safe can become a Root Safe into On-chain Organization, and handle a different leaf.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (createRootSafe) to Palmera Module
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (createRootSafe) to Palmera Module
    S->>PM: Execute the Transaction
    opt New Root Safe Register Process
        PM-->>+PM: Validate the Safe Proxy is not Registered
        PM-->>+PM: Validate the Caller is a Root Safe
        PM-->>+O: Register the New Root Safe
    end
    PM->>OW: Get Safe Proxy Hash Registered
```

#### Remove a Safe

Function: removeSafe()
Description: Removes a safe. This must be called by the root safe.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (removeSafe) to Palmera Module
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (removeSafe) to Palmera Module
    S->>PM: Execute the Transaction
    opt Safe Remove Process
        PM-->>+PM: Validate the Caller is a Root Safe or Super Safe
        PM-->>+PM: Validate the Safe Proxy is Registered
        PM-->>+O: Remove the Safe Proxy
    end
    PM->>OW: Get Safe Proxy Hash Removed
```

#### Disconnect a Safe

Function: disconnectSafe()
Description: Disconnects a safe from the organization. This must be called by the root safe.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+S: Submit Create the Transaction 
    Note over OW,S: Call Data to Execute (disconnectSafe) to Palmera Module
    S-->>OW: Transaction Created
    Note over OW,S: Estimation of Gas is OK
    OW->>+S: Submit Execute the Transaction
    Note over OW,S: Call Data to Execute (disconnectSafe) to Palmera Module
    S->>PM: Execute the Transaction
    opt Safe Disconnect Process
        PM-->>+PM: Validate the Caller is a Root Safe or Super Safe
        PM-->>+PM: Validate the Safe Proxy is Registered
        PM-->>+O: Disconnect the Safe Proxy
    end
    PM->>OW: Get Safe Proxy Hash Disconnected
```

#### Execute a Transaction on Behalf Of

Function: execTransactionOnBehalf()
Description: Allows a root/super safe or safe lead to execute transactions on behalf of a sub/child safe.

```mermaid
sequenceDiagram
    actor OW as Owner
    participant S as Root Safe Proxy
    participant PM as Palmera Module
    actor O as Organization

    OW->>+PM: Request nonce of Root/Target Safe Organization
    PM-->>OW: Get nonce of Root/Target Safe Organization
    OW->>+PM: Request Transaction Hash of Arguments <br> to Execute Transaction on Behalf
    PM-->>OW: Get Transaction Hash of Arguments
    OW->>+S: Sign Transaction Hash of Arguments <br> to Execute Transaction on Behalf with Root Safe
    S->>+OW: Get Signature Call Data
    OW->>PM: Send the Transaction
    opt Execute Transaction on Behalf Process
        PM-->>+PM: Validate the Caller is a HasPemissions over Target Safe
        PM-->>+PM: Validate the Org of Target Safe is Registered
        PM-->>+PM: Validate the Target Safe is Registered
        PM-->>+PM: Validate the Signature Call Data is OK
        PM-->>+O: Execute the Transaction on Behalf
    end
    PM->>OW: Get Transaction Executed
```
