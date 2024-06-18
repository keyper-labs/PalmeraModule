# Palmera Module Principal of Diagrmas - Technical Specification

## Table of Contents

- Project Overview
- Functional Requirements
  - 1.1. Enable Module and Guard
  - 1.2. Roles and Authorizations
  - 1.3. Features
  - 1.4. Business Logic
  - 1.5. Use Cases
- Technical Requirements
  - 2.1. Deployment Instructions
  - 2.2. Architectural Overview
  - 2.3. Contract Information

## Project Overview

The Palmera Module is an orchestration framework for On-Chain Organizations based on the Safe ecosystem, enabling the creation and management of hierarchies and permissions within On-Chain Organizations. It extends the capabilities of Safe’s multisig wallet to manage assets and treasury in a secure and hierarchical manner. More Details in [Palmera Module Docs](https://docs.palmeradao.xyz/palmera).

## Functional Requirements

### 1.1. Enable Module and Guard

if you wanna to see in details the process to Enable Module and Set Guard, follow the docs and diagrams in:

- To Enable Module: [Safe Modules](https://docs.safe.global/advanced/smart-account-modules)
- Set Guard: [Safe Guard](https://docs.safe.global/advanced/smart-account-guards)

### 1.2. Roles and Authorizations

In this point we see the initial setup between Palmera Roles and Palmera Module, for Setup the Roles using the Solmete Auth / Roles Library

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
