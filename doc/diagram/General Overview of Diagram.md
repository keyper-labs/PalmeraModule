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

#### 1.1.1. Enable Module

```mermaid
sequenceDiagram
    actor B as Owner EOA
    participant E as Safe Proxy
    participant P as Safe Singleton
    actor T as Target

    B->>+E: Submit Enable Module
    E->>+P: Validate Enable Module
    E->>+P: Execute User Operation
    P->>+E: Perform transaction
    opt Bubble up return data
        E-->>-A: Call return data
    end
```

### 1.2. Roles and Authorizations

```mermaid
sequenceDiagram
    actor B as Bundler
    participant E as Entry Point
    participant P as Safe Proxy
    participant S as Safe Singleton
    participant M as Safe 4337 Module
    actor T as Target

    B->>+E: Submit User Operations
    E->>+P: Validate User Operation
    P-->>S: Load Safe logic
    Note over P, M: Gas overhead for calls and storage access
    P->>+M: Forward validation
    Note over P, M: Load fallback handler ~2100 gas<br>Intital module access ~2600 gas
    M->>P: Check signatures
    P-->>S: Load Safe logic
    Note over P, M: Call to Safe Proxy ~100 gas<br>Load logic ~100 gas
    opt Pay required fee
        M->>P: Trigger fee payment
        P-->>S: Load Safe logic
        Note over P, M: Module check ~2100 gas<br>Call to Safe Proxy ~100 gas<br>Load logic ~100 gas
        P->>E: Perform fee payment
    end
    M-->>-P: Validation response
    P-->>-E: Validation response
    Note over P, M: Total gas overhead<br>Without fee payment ~4.900 gas<br>With fee payment ~7.200 gas

    E->>+P: Execute User Operation
    P-->>S: Load Safe logic
    P->>+M: Forward execution
    Note over P, M: Call to Safe Proxy ~100 gas<br>Call to fallback handler ~100 gas
    M->>P: Execute From Module
    P-->>S: Load Safe logic
    Note over P, M: Call to Safe Proxy ~100 gas<br>Module check ~100 gas
    P->>+T: Perform transaction
    opt Bubble up return data
        T-->>-P: Call Return Data
        P-->>M: Call Return Data
        M-->>-P: Call return data
        P-->>-E: Call return data
    end
```