// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {SignatureDecoder} from "@safe-contracts/common/SignatureDecoder.sol";
import {ISignatureValidator} from
    "@safe-contracts/interfaces/ISignatureValidator.sol";
import {ISignatureValidatorConstants} from
    "@safe-contracts/interfaces/ISignatureValidator.sol";
import {IGnosisSafe, IGnosisSafeProxy} from "./GnosisSafeInterfaces.sol";

contract KeyperModule is SignatureDecoder, ISignatureValidatorConstants {
    string public constant NAME = "Keyper Module";
    string public constant VERSION = "0.1.0";

    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "KeyperTx(address org,address safe,address to,uint256 value,bytes data,uint8 operation,uint256 nonce)"
    // );
    bytes32 private constant KEYPER_TX_TYPEHASH =
        0xbb667b7bf67815e546e48fb8d0e6af5c31fe53b9967ed45225c9d55be21652da;

    address public constant FALLBACK_HANDLER =
        0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

    // Safe contracts
    address public immutable masterCopy;
    address public immutable proxyFactory;

    // Orgs -> Groups
    mapping(address => mapping(address => Group)) public groups;

    // Orgs info
    mapping(address => Group) public orgs;

    uint256 public nonce;
    address internal constant SENTINEL_OWNERS = address(0x1);

    // Events
    event OrganisationCreated(address indexed org, string name);

    event GroupCreated(
        address indexed org,
        address indexed group,
        string name,
        address indexed admin,
        address parent
    );

    event TxOnBehalfExecuted(
        address indexed org,
        address indexed executor,
        address indexed target,
        bool result
    );

    event ModuleEnabled(address indexed safe, address indexed module);

    // Errors
    error OrgNotRegistered();
    error GroupNotRegistered();
    error ParentNotRegistered();
    error AdminNotRegistered();
    error NotAuthorized();
    error NotAuthorizedExecOnBehalf();
    error CreateSafeProxyFailed();

    struct Group {
        string name;
        address admin;
        address safe;
        address[] childs;
        address parent;
    }

    struct TransactionHelper {
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
    }

    constructor(address masterCopyAddress, address proxyFactoryAddress) {
        require(masterCopyAddress != address(0));
        require(proxyFactoryAddress != address(0));

        masterCopy = masterCopyAddress;
        proxyFactory = proxyFactoryAddress;
    }

    function createSafeProxy(address[] memory owners, uint256 threshold)
        external
        returns (address safe)
    {
        bytes memory internalEnableModuleData =
            abi.encodeWithSignature("internalEnableModule(address)", address(this));

        bytes memory data = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            this,
            internalEnableModuleData,
            FALLBACK_HANDLER,
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        IGnosisSafeProxy gnosisSafeProxy = IGnosisSafeProxy(proxyFactory);
        try gnosisSafeProxy.createProxy(masterCopy, data) returns (address newSafe) {
            return newSafe;
        } catch {
            revert CreateSafeProxyFailed();
        }
    }

    /**
     @notice Function executed when user creates a Gnosis Safe wallet via GnosisSafeProxyFactory::createProxyWithCallback
             enabling keyper module as the callback.
     */
    function proxyCreated(
        IGnosisSafeProxy proxy,
        address singleton,
        bytes calldata initializer,
        uint256
    )
        external
    {
        // Ensure correct factory and master copy
        // require(msg.sender == proxyFactory, "Caller must be factory");
        // console.log(msg.sender);
        require(singleton == masterCopy, "Fake mastercopy used");

        // Ensure initial calldata was a call to `GnosisSafe::setup`
        require(
            bytes4(initializer[:4]) == bytes4(0xb63e800d), "Wrong initialization"
        );

        // Call enableKeyperModule on new created safe
        bytes memory enableTx =
            abi.encodeWithSignature("enableKeyperModule(address)", address(this));

        // External call safe as proxy address coming from gnosisFactory smart contract
        (bool success,) = address(proxy).call(enableTx);
        require(success, "Enable module failed");
    }

    function getOrg(address _org)
        public
        view
        returns (string memory, address, address, address)
    {
        require(_org != address(0));
        if (orgs[_org].safe == address(0)) revert OrgNotRegistered();
        return (
            orgs[_org].name,
            orgs[_org].admin,
            orgs[_org].safe,
            orgs[_org].parent
        );
    }

    /// @notice Register an organisatin
    /// @dev Call has to be done from a safe transaction
    /// @param name of the org
    function registerOrg(string memory name) public {
        Group storage rootOrg = orgs[msg.sender];
        rootOrg.admin = msg.sender;
        rootOrg.name = name;
        rootOrg.safe = msg.sender;

        emit OrganisationCreated(msg.sender, name);
    }

    /// @notice check if the organisation is registered
    /// @param org address
    function isOrgRegistered(address org) public view returns (bool) {
        if (orgs[org].safe == address(0)) {
            return false;
        }
        return true;
    }

    /// @notice Add a group to an organisation/group
    /// @dev Call coming from the group safe
    /// @param org address of the organisation
    /// @param parent address of the parent
    /// @param name name of the group
    function addGroup(address org, address parent, string memory name)
        public
    {
        if (orgs[org].safe == address(0)) revert OrgNotRegistered();
        Group storage newGroup = groups[org][msg.sender];
        // Add to org root
        if (parent == org) {
            // By default Admin of the new group is the admin of the org
            newGroup.admin = orgs[org].admin;
            Group storage parentOrg = orgs[org];
            parentOrg.childs.push(msg.sender);
        }
        // Add to group
        else {
            if (groups[org][parent].safe == address(0))
            revert ParentNotRegistered();
            // By default Admin of the new group is the admin of the parent (TODO check this)
            newGroup.admin = groups[org][parent].admin;
            Group storage parentGroup = groups[org][parent];
            parentGroup.childs.push(msg.sender);
        }
        newGroup.parent = parent;
        newGroup.safe = msg.sender;
        newGroup.name = name;
        emit GroupCreated(org, msg.sender, name, newGroup.admin, parent);
    }

    /// @notice Get all the information about a group
    function getGroupInfo(address org, address group)
        public
        view
        returns (string memory, address, address, address)
    {
        address groupSafe = groups[org][group].safe;
        if (groupSafe == address(0)) revert OrgNotRegistered();

        return (
            groups[org][group].name,
            groups[org][group].admin,
            groups[org][group].safe,
            groups[org][group].parent
        );
    }

    /// @notice Check if child address is part of the group within an organisation
    function isChild(address org, address parent, address child)
        public
        view
        returns (bool)
    {
        if (orgs[org].safe == address(0)) revert OrgNotRegistered();
        // Check within orgs first if parent is an organisation
        if (org == parent) {
            Group memory organisation = orgs[org];
            for (uint256 i = 0; i < organisation.childs.length; i++) {
                if (organisation.childs[i] == child) return true;
            }
        }
        // Check within groups of the org
        if (groups[org][parent].safe == address(0)) revert ParentNotRegistered();
        Group memory group = groups[org][parent];
        for (uint256 i = 0; i < group.childs.length; i++) {
            if (group.childs[i] == child) return true;
        }
        return false;
    }

    /// @notice Check if an org is admin of the group
    function isAdmin(address org, address group) public view returns (bool) {
        if (orgs[org].safe == address(0)) return false;
        // Check group admin
        Group memory _group = groups[org][group];
        if (_group.admin == org) {
            return true;
        }
        return false;
    }

    /// @notice Check if the group is a parent of another group
    function isParent(address org, address parent, address child)
        public
        view
        returns (bool)
    {
        Group memory childGroup = groups[org][child];
        address curentParent = childGroup.parent;
        // TODO: probably more efficient to just create a parents mapping instead of this iterations
        while (curentParent != address(0)) {
            if (curentParent == parent) return true;
            childGroup = groups[org][curentParent];
            curentParent = childGroup.parent;
        }
        return false;
    }

    /// @notice Calls execTransaction of the safe with custom checks on owners rights
    /// @param org Organisation
    /// @param safe Safe target address
    /// @param to data
    function execTransactionOnBehalf(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    )
        external
        payable
        returns (bool success)
    {
        // Check msg.sender is an admin of the target safe
        if (!isAdmin(msg.sender, safe) && !isParent(org, msg.sender, safe)) {
            // Check if it a then parent
            revert NotAuthorizedExecOnBehalf();
        }

        bytes32 txHash;
        // Use scope here to limit variable lifetime and prevent `stack too deep` errors
        {
            bytes memory keyperTxHashData = encodeTransactionData(
                // Keyper Info
                msg.sender,
                safe,
                // Transaction info
                to,
                value,
                data,
                operation,
                // Signature info
                nonce
            );
            // Increase nonce and execute transaction.
            nonce++;
            txHash = keccak256(keyperTxHashData);
            checkNSignatures(txHash, keyperTxHashData, signatures);
            // Execute transaction from safe
            IGnosisSafe gnosisSafe = IGnosisSafe(safe);
            bool result =
                gnosisSafe.execTransactionFromModule(to, value, data, operation);
            emit TxOnBehalfExecuted(org, msg.sender, safe, result);
            return result;
        }
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this)
            );
    }

    /// @dev Returns the chain id used by this contract.
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
     * @param dataHash Hash of the data (could be either a message hash or transaction hash)
     * @param data That should be signed (this is passed to an external validator contract)
     * @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
     * @dev Call must come from a safe
     */
    function checkNSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    )
        public
        view
    {
        IGnosisSafe gnosisSafe = IGnosisSafe(msg.sender);
        uint256 requiredSignatures = gnosisSafe.getThreshold();
        // Check that the provided signature data is not too short
        require(signatures.length >= requiredSignatures * 65, "GS020");
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                require(uint256(s) >= requiredSignatures * 65, "GS021");

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                require(uint256(s) + 32 <= signatures.length, "GS022");

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(
                    uint256(s) + 32 + contractSignatureLen <= signatures.length,
                    "GS023"
                );

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                require(
                    ISignatureValidator(currentOwner).isValidSignature(data, contractSignature)
                        == EIP1271_MAGIC_VALUE,
                    "GS024"
                ); // }
                // TODO: Identify this usecase
                // else if (v == 1) {
                //     // If v is 1 then it is an approved hash
                //     // When handling approved hashes the address of the approver is encoded into r
                //     currentOwner = address(uint160(uint256(r)));
                //     // Hashes are automatically approved by the sender of the message or when they have been pre-approved via a separate transaction
                //     require(msg.sender == currentOwner || approvedHashes[currentOwner][dataHash] != 0, "GS025");
            //
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                currentOwner = ecrecover(
                    keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)),
                    v - 4,
                    r,
                    s
                );
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(
                currentOwner > lastOwner && currentOwner != SENTINEL_OWNERS, "GS026"
            );
            // TODO change this logic, not optimized: Check current owner is part of the owners of the org safe
            require(isSafeOwner(gnosisSafe, currentOwner) != false, "GS026");
            lastOwner = currentOwner;
        }
    }

    function isSafeOwner(IGnosisSafe gnosisSafe, address signer)
        private
        view
        returns (bool)
    {
        address[] memory safeOwners = gnosisSafe.getOwners();
        for (uint256 i = 0; i < safeOwners.length; i++) {
            if (safeOwners[i] == signer) {
                return true;
            }
        }
        return false;
    }

    function encodeTransactionData(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    )
        public
        view
        returns (bytes memory)
    {
        bytes32 keyperTxHash = keccak256(
            abi.encode(
                KEYPER_TX_TYPEHASH, org, safe, to, value, keccak256(data), operation, _nonce
            )
        );
        return
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator(),
                keyperTxHash
            );
    }

    function getTransactionHash(
        address org,
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 _nonce
    )
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                encodeTransactionData(
                    org,
                    safe,
                    to,
                    value,
                    data,
                    operation,
                    _nonce
                )
            );
    }

    function internalEnableModule(address module) external {
        this.enableModule(module);
    }

    // Non-executed code, function called by the new safe
    function enableModule(address module) external {
        emit ModuleEnabled(address(this), module);
    }
}