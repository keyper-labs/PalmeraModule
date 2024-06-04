export const palmeraModuleAbi = [
    {
        "type": "constructor",
        "inputs": [
            {
                "name": "authorityAddress",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "maxDepthTreeLimitInitial",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "fallback",
        "stateMutability": "nonpayable"
    },
    {
        "type": "receive",
        "stateMutability": "payable"
    },
    {
        "type": "function",
        "name": "NAME",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "string",
                "internalType": "string"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "VERSION",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "string",
                "internalType": "string"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "addOwnerWithThreshold",
        "inputs": [
            {
                "name": "ownerAdded",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "threshold",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "addSafe",
        "inputs": [
            {
                "name": "superSafe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "name",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [
            {
                "name": "safeId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "addToList",
        "inputs": [
            {
                "name": "users",
                "type": "address[]",
                "internalType": "address[]"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "allowFeature",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "authority",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "contract Authority"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "createRootSafe",
        "inputs": [
            {
                "name": "newRootSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "name",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [
            {
                "name": "safeId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "denyFeature",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "depthTreeLimit",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "disableDenyHelper",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "disconnectSafe",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "domainSeparator",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "dropFromList",
        "inputs": [
            {
                "name": "user",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "enableAllowlist",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "enableDenylist",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "encodeTransactionData",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "superSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "to",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "value",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "data",
                "type": "bytes",
                "internalType": "bytes"
            },
            {
                "name": "operation",
                "type": "uint8",
                "internalType": "enum Enum.Operation"
            },
            {
                "name": "_nonce",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bytes",
                "internalType": "bytes"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "execTransactionOnBehalf",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "superSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "to",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "value",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "data",
                "type": "bytes",
                "internalType": "bytes"
            },
            {
                "name": "operation",
                "type": "uint8",
                "internalType": "enum Enum.Operation"
            },
            {
                "name": "signatures",
                "type": "bytes",
                "internalType": "bytes"
            }
        ],
        "outputs": [
            {
                "name": "result",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "payable"
    },
    {
        "type": "function",
        "name": "getChainId",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getOrgBySafe",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "orgSafe",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getOrgHashBySafe",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getPrevUser",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "wallet",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "prevUser",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getRootSafe",
        "inputs": [
            {
                "name": "safeId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "rootSafeId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getSafeAddress",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getSafeIdBySafe",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getSafeInfo",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint8",
                "internalType": "enum DataTypes.Tier"
            },
            {
                "name": "",
                "type": "string",
                "internalType": "string"
            },
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "",
                "type": "uint256[]",
                "internalType": "uint256[]"
            },
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getTransactionHash",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "superSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "to",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "value",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "data",
                "type": "bytes",
                "internalType": "bytes"
            },
            {
                "name": "operation",
                "type": "uint8",
                "internalType": "enum Enum.Operation"
            },
            {
                "name": "_nonce",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "hasNotPermissionOverTarget",
        "inputs": [
            {
                "name": "caller",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "hasPermission",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "indexId",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "indexSafe",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isLimitLevel",
        "inputs": [
            {
                "name": "superSafe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isListed",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "wallet",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isOrgRegistered",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isPendingRemove",
        "inputs": [
            {
                "name": "rootSafe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isRootSafeOf",
        "inputs": [
            {
                "name": "root",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isSafe",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isSafeLead",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "user",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isSafeRegistered",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isSuperSafe",
        "inputs": [
            {
                "name": "superSafe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isTreeMember",
        "inputs": [
            {
                "name": "superSafe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "isMember",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "listCount",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nonce",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "owner",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "promoteRoot",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "registerOrg",
        "inputs": [
            {
                "name": "orgName",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [
            {
                "name": "safeId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "removeOwner",
        "inputs": [
            {
                "name": "prevOwner",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "ownerRemoved",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "threshold",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "targetSafe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "removeSafe",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "removeWholeTree",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "safes",
        "inputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "tier",
                "type": "uint8",
                "internalType": "enum DataTypes.Tier"
            },
            {
                "name": "name",
                "type": "string",
                "internalType": "string"
            },
            {
                "name": "lead",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "superSafe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "setAuthority",
        "inputs": [
            {
                "name": "newAuthority",
                "type": "address",
                "internalType": "contract Authority"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setOwner",
        "inputs": [
            {
                "name": "newOwner",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setRole",
        "inputs": [
            {
                "name": "role",
                "type": "uint8",
                "internalType": "enum DataTypes.Role"
            },
            {
                "name": "user",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "enabled",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "updateDepthTreeLimit",
        "inputs": [
            {
                "name": "newLimit",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "updateSuper",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "newSuper",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "event",
        "name": "AddedToList",
        "inputs": [
            {
                "name": "users",
                "type": "address[]",
                "indexed": false,
                "internalType": "address[]"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "AuthorityUpdated",
        "inputs": [
            {
                "name": "user",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "newAuthority",
                "type": "address",
                "indexed": true,
                "internalType": "contract Authority"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "DroppedFromList",
        "inputs": [
            {
                "name": "user",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "NewLimitLevel",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "rootSafeId",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "updater",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "oldLimit",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "newLimit",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "OrganisationCreated",
        "inputs": [
            {
                "name": "creator",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "OwnerUpdated",
        "inputs": [
            {
                "name": "user",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "newOwner",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "RootSafeCreated",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "newIdRootSafe",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "creator",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "newRootSafe",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "RootSafePromoted",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "newIdRootSafe",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "updater",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "newRootSafe",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "SafeCreated",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "safeCreated",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "lead",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "creator",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "superSafe",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "SafeDisconnected",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "safeId",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "safe",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "disconnector",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "SafeRemoved",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "safeRemoved",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "lead",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "remover",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "superSafe",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "SafeSuperUpdated",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "safeUpdated",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "lead",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "updater",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "oldSuperSafe",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "newSuperSafe",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "TxOnBehalfExecuted",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "executor",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "superSafe",
                "type": "address",
                "indexed": false,
                "internalType": "address"
            },
            {
                "name": "target",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "result",
                "type": "bool",
                "indexed": false,
                "internalType": "bool"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "WholeTreeRemoved",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "rootSafeId",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "remover",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "name",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "error",
        "name": "AddresNotAllowed",
        "inputs": []
    },
    {
        "type": "error",
        "name": "AddressDenied",
        "inputs": []
    },
    {
        "type": "error",
        "name": "CannotRemoveSafeBeforeRemoveChild",
        "inputs": [
            {
                "name": "children",
                "type": "uint256",
                "internalType": "uint256"
            }
        ]
    },
    {
        "type": "error",
        "name": "DenyHelpersDisabled",
        "inputs": []
    },
    {
        "type": "error",
        "name": "EmptyName",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidAddressProvided",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidLimit",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidRootSafe",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "InvalidSafe",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "InvalidSafeId",
        "inputs": []
    },
    {
        "type": "error",
        "name": "ListEmpty",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedAddOwnerWithThreshold",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedAsNotRootOrSuperSafe",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedDisconnectChildrenSafe",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedExecOnBehalf",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedRemoveOwner",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedSetRoleAnotherTree",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedUpdateNonChildrenSafe",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedUpdateNonSuperSafe",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotAuthorizedUpdateSafeToOtherOrg",
        "inputs": []
    },
    {
        "type": "error",
        "name": "NotPermittedReceiveEther",
        "inputs": []
    },
    {
        "type": "error",
        "name": "OrgAlreadyRegistered",
        "inputs": [
            {
                "name": "safe",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ]
    },
    {
        "type": "error",
        "name": "OrgNotRegistered",
        "inputs": [
            {
                "name": "org",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ]
    },
    {
        "type": "error",
        "name": "OwnerAlreadyExists",
        "inputs": []
    },
    {
        "type": "error",
        "name": "OwnerNotFound",
        "inputs": []
    },
    {
        "type": "error",
        "name": "PreviewModuleNotFound",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "SafeAlreadyRegistered",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "SafeAlreadyRemoved",
        "inputs": []
    },
    {
        "type": "error",
        "name": "SafeIdNotRegistered",
        "inputs": [
            {
                "name": "safe",
                "type": "uint256",
                "internalType": "uint256"
            }
        ]
    },
    {
        "type": "error",
        "name": "SafeNotRegistered",
        "inputs": [
            {
                "name": "safe",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "SetRoleForbidden",
        "inputs": [
            {
                "name": "role",
                "type": "uint8",
                "internalType": "enum DataTypes.Role"
            }
        ]
    },
    {
        "type": "error",
        "name": "TreeDepthLimitReached",
        "inputs": [
            {
                "name": "limit",
                "type": "uint256",
                "internalType": "uint256"
            }
        ]
    },
    {
        "type": "error",
        "name": "TxExecutionModuleFailed",
        "inputs": []
    },
    {
        "type": "error",
        "name": "TxOnBehalfExecutedFailed",
        "inputs": []
    },
    {
        "type": "error",
        "name": "UserAlreadyOnList",
        "inputs": []
    },
    {
        "type": "error",
        "name": "ZeroAddressProvided",
        "inputs": []
    }
]

export const safeAbi = [
    { inputs: [], stateMutability: "nonpayable", type: "constructor" },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "owner",
                type: "address",
            },
        ],
        name: "AddedOwner",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "approvedHash",
                type: "bytes32",
            },
            {
                indexed: true,
                internalType: "address",
                name: "owner",
                type: "address",
            },
        ],
        name: "ApproveHash",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "handler",
                type: "address",
            },
        ],
        name: "ChangedFallbackHandler",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "guard",
                type: "address",
            },
        ],
        name: "ChangedGuard",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "uint256",
                name: "threshold",
                type: "uint256",
            },
        ],
        name: "ChangedThreshold",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "module",
                type: "address",
            },
        ],
        name: "DisabledModule",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "module",
                type: "address",
            },
        ],
        name: "EnabledModule",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "txHash",
                type: "bytes32",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "payment",
                type: "uint256",
            },
        ],
        name: "ExecutionFailure",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "module",
                type: "address",
            },
        ],
        name: "ExecutionFromModuleFailure",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "module",
                type: "address",
            },
        ],
        name: "ExecutionFromModuleSuccess",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "txHash",
                type: "bytes32",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "payment",
                type: "uint256",
            },
        ],
        name: "ExecutionSuccess",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "owner",
                type: "address",
            },
        ],
        name: "RemovedOwner",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "sender",
                type: "address",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "value",
                type: "uint256",
            },
        ],
        name: "SafeReceived",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "initiator",
                type: "address",
            },
            {
                indexed: false,
                internalType: "address[]",
                name: "owners",
                type: "address[]",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "threshold",
                type: "uint256",
            },
            {
                indexed: false,
                internalType: "address",
                name: "initializer",
                type: "address",
            },
            {
                indexed: false,
                internalType: "address",
                name: "fallbackHandler",
                type: "address",
            },
        ],
        name: "SafeSetup",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "msgHash",
                type: "bytes32",
            },
        ],
        name: "SignMsg",
        type: "event",
    },
    { stateMutability: "nonpayable", type: "fallback" },
    {
        inputs: [],
        name: "VERSION",
        outputs: [{ internalType: "string", name: "", type: "string" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "owner", type: "address" },
            { internalType: "uint256", name: "_threshold", type: "uint256" },
        ],
        name: "addOwnerWithThreshold",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "bytes32", name: "hashToApprove", type: "bytes32" },
        ],
        name: "approveHash",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "", type: "address" },
            { internalType: "bytes32", name: "", type: "bytes32" },
        ],
        name: "approvedHashes",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [{ internalType: "uint256", name: "_threshold", type: "uint256" }],
        name: "changeThreshold",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "bytes32", name: "dataHash", type: "bytes32" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "bytes", name: "signatures", type: "bytes" },
            { internalType: "uint256", name: "requiredSignatures", type: "uint256" },
        ],
        name: "checkNSignatures",
        outputs: [],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "bytes32", name: "dataHash", type: "bytes32" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "bytes", name: "signatures", type: "bytes" },
        ],
        name: "checkSignatures",
        outputs: [],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "prevModule", type: "address" },
            { internalType: "address", name: "module", type: "address" },
        ],
        name: "disableModule",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "domainSeparator",
        outputs: [{ internalType: "bytes32", name: "", type: "bytes32" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "module", type: "address" }],
        name: "enableModule",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "uint256", name: "value", type: "uint256" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "enum Enum.Operation", name: "operation", type: "uint8" },
            { internalType: "uint256", name: "safeTxGas", type: "uint256" },
            { internalType: "uint256", name: "baseGas", type: "uint256" },
            { internalType: "uint256", name: "gasPrice", type: "uint256" },
            { internalType: "address", name: "gasToken", type: "address" },
            { internalType: "address", name: "refundReceiver", type: "address" },
            { internalType: "uint256", name: "_nonce", type: "uint256" },
        ],
        name: "encodeTransactionData",
        outputs: [{ internalType: "bytes", name: "", type: "bytes" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "uint256", name: "value", type: "uint256" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "enum Enum.Operation", name: "operation", type: "uint8" },
            { internalType: "uint256", name: "safeTxGas", type: "uint256" },
            { internalType: "uint256", name: "baseGas", type: "uint256" },
            { internalType: "uint256", name: "gasPrice", type: "uint256" },
            { internalType: "address", name: "gasToken", type: "address" },
            {
                internalType: "address payable",
                name: "refundReceiver",
                type: "address",
            },
            { internalType: "bytes", name: "signatures", type: "bytes" },
        ],
        name: "execTransaction",
        outputs: [{ internalType: "bool", name: "success", type: "bool" }],
        stateMutability: "payable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "uint256", name: "value", type: "uint256" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "enum Enum.Operation", name: "operation", type: "uint8" },
        ],
        name: "execTransactionFromModule",
        outputs: [{ internalType: "bool", name: "success", type: "bool" }],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "uint256", name: "value", type: "uint256" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "enum Enum.Operation", name: "operation", type: "uint8" },
        ],
        name: "execTransactionFromModuleReturnData",
        outputs: [
            { internalType: "bool", name: "success", type: "bool" },
            { internalType: "bytes", name: "returnData", type: "bytes" },
        ],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "getChainId",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "start", type: "address" },
            { internalType: "uint256", name: "pageSize", type: "uint256" },
        ],
        name: "getModulesPaginated",
        outputs: [
            { internalType: "address[]", name: "array", type: "address[]" },
            { internalType: "address", name: "next", type: "address" },
        ],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getOwners",
        outputs: [{ internalType: "address[]", name: "", type: "address[]" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "uint256", name: "offset", type: "uint256" },
            { internalType: "uint256", name: "length", type: "uint256" },
        ],
        name: "getStorageAt",
        outputs: [{ internalType: "bytes", name: "", type: "bytes" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getThreshold",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "uint256", name: "value", type: "uint256" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "enum Enum.Operation", name: "operation", type: "uint8" },
            { internalType: "uint256", name: "safeTxGas", type: "uint256" },
            { internalType: "uint256", name: "baseGas", type: "uint256" },
            { internalType: "uint256", name: "gasPrice", type: "uint256" },
            { internalType: "address", name: "gasToken", type: "address" },
            { internalType: "address", name: "refundReceiver", type: "address" },
            { internalType: "uint256", name: "_nonce", type: "uint256" },
        ],
        name: "getTransactionHash",
        outputs: [{ internalType: "bytes32", name: "", type: "bytes32" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "module", type: "address" }],
        name: "isModuleEnabled",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "owner", type: "address" }],
        name: "isOwner",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "nonce",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "prevOwner", type: "address" },
            { internalType: "address", name: "owner", type: "address" },
            { internalType: "uint256", name: "_threshold", type: "uint256" },
        ],
        name: "removeOwner",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "handler", type: "address" }],
        name: "setFallbackHandler",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "guard", type: "address" }],
        name: "setGuard",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address[]", name: "_owners", type: "address[]" },
            { internalType: "uint256", name: "_threshold", type: "uint256" },
            { internalType: "address", name: "to", type: "address" },
            { internalType: "bytes", name: "data", type: "bytes" },
            { internalType: "address", name: "fallbackHandler", type: "address" },
            { internalType: "address", name: "paymentToken", type: "address" },
            { internalType: "uint256", name: "payment", type: "uint256" },
            {
                internalType: "address payable",
                name: "paymentReceiver",
                type: "address",
            },
        ],
        name: "setup",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [{ internalType: "bytes32", name: "", type: "bytes32" }],
        name: "signedMessages",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "targetContract", type: "address" },
            { internalType: "bytes", name: "calldataPayload", type: "bytes" },
        ],
        name: "simulateAndRevert",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "prevOwner", type: "address" },
            { internalType: "address", name: "oldOwner", type: "address" },
            { internalType: "address", name: "newOwner", type: "address" },
        ],
        name: "swapOwner",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    { stateMutability: "payable", type: "receive" },
];