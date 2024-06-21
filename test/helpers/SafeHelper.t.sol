/// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/SigningUtils.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "../../script/DeploySafeFactory.t.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {DataTypes} from "../../src/libraries/DataTypes.sol";
import {Random} from "./Random.sol";

/// @notice Helper contract handling deployment Safe contracts
/// @custom:security-contact general@palmeradao.xyz
contract SafeHelper is Test, SigningUtils, SignDigestHelper, SignersHelper {
    GnosisSafe public safeWallet;
    DeploySafeFactory public safeFactory;

    address public palmeraRolesAddr;
    address public palmeraModuleAddr;
    address public palmeraGuardAddr;
    address public safeMasterCopy;

    uint256 public salt;

    /// Create new safe test environment
    /// Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    /// Init signers
    /// Deploy a new safe proxy
    /// @return address of the new safe
    function setupSafeEnv() public returns (address) {
        safeFactory = new DeploySafeFactory();
        safeFactory.run();
        safeMasterCopy = address(safeFactory.safeContract());
        bytes memory emptyData;
        address safeWalletProxy = safeFactory.newSafeProxy(emptyData);
        safeWallet = GnosisSafe(payable(safeWalletProxy));
        initOnwers(30);

        /// Setup safe with 3 owners, 1 threshold
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        /// Update privateKeyOwners used
        updateCount(3);

        safeWallet.setup(
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        return address(safeWallet);
    }

    /// Create new safe test environment
    /// Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    /// Init signers
    /// Permit create a specific numbers of owners
    /// Deploy a new safe proxy
    /// @param initOwners number of owners to initialize
    /// @return address of the new safe
    function setupSeveralSafeEnv(uint256 initOwners)
        public
        virtual
        returns (address)
    {
        safeFactory = new DeploySafeFactory();
        safeFactory.run();
        safeMasterCopy = address(safeFactory.safeContract());
        salt++;
        bytes memory emptyData = abi.encodePacked(salt);
        address safeWalletProxy = safeFactory.newSafeProxy(emptyData);
        safeWallet = GnosisSafe(payable(safeWalletProxy));
        initOnwers(initOwners);

        /// Setup safe with 3 owners, 1 threshold
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        /// Update privateKeyOwners used
        updateCount(3);

        safeWallet.setup(
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        return address(safeWallet);
    }

    /// function to set palmeraRoles address
    /// @param palmeraRoles palmeraRoles address
    function setPalmeraRoles(address palmeraRoles) public {
        palmeraRolesAddr = palmeraRoles;
    }

    /// function to set palmeraModule address
    /// @param palmeraModule palmeraModule address
    function setPalmeraModule(address palmeraModule) public virtual {
        palmeraModuleAddr = palmeraModule;
    }

    /// function to set palmeraGuard address
    /// @param palmeraGuard palmeraGuard address
    function setPalmeraGuard(address palmeraGuard) public {
        palmeraGuardAddr = palmeraGuard;
    }

    /// function to create Safe with Palmera and send module enabled tx
    /// @param numberOwners number of owners
    /// @param threshold threshold
    /// @return address of the new safe
    function newPalmeraSafe(uint256 numberOwners, uint256 threshold)
        public
        virtual
        returns (address)
    {
        require(
            privateKeyOwners.length >= numberOwners,
            "not enough initialized owners"
        );
        require(
            countUsed + numberOwners <= privateKeyOwners.length,
            "No private keys available"
        );
        require(palmeraModuleAddr != address(0), "Palmera module not set");
        address[] memory owners = new address[](numberOwners);
        for (uint256 i; i < numberOwners; ++i) {
            owners[i] = vm.addr(privateKeyOwners[i + countUsed]);
            countUsed++;
        }
        bytes memory emptyData;
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        address safeWalletProxy = safeFactory.newSafeProxy(initializer);
        safeWallet = GnosisSafe(payable(address(safeWalletProxy)));

        /// Enable module
        bool result = enableModuleTx(address(safeWallet));
        require(result == true, "failed enable module");

        /// Enable Guard
        result = enableGuardTx(address(safeWallet));
        require(result == true, "failed enable guard");
        return address(safeWallet);
    }

    /// fucntion to create Safe with Palmera and send module enabled tx
    /// @param numberOwners number of owners
    /// @param threshold threshold
    /// @return address of the new safe
    function newPalmeraSafeWithPKOwners(uint256 numberOwners, uint256 threshold)
        public
        virtual
        returns (address, uint256[] memory)
    {
        uint256[] memory ownersPK = new uint256[](numberOwners);
        require(
            privateKeyOwners.length >= numberOwners,
            "not enough initialized owners"
        );
        require(
            countUsed + numberOwners <= privateKeyOwners.length,
            "No private keys available"
        );
        require(palmeraModuleAddr != address(0), "Palmera module not set");
        address[] memory owners = new address[](numberOwners);
        for (uint256 i; i < numberOwners; ++i) {
            ownersPK[i] = privateKeyOwners[i + countUsed];
            owners[i] = vm.addr(privateKeyOwners[i + countUsed]);
            countUsed++;
        }
        bytes memory emptyData;
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        address safeWalletProxy = safeFactory.newSafeProxy(initializer);
        safeWallet = GnosisSafe(payable(address(safeWalletProxy)));

        /// Enable module
        bool result = enableModuleTx(address(safeWallet));
        require(result == true, "failed enable module");

        /// Enable Guard
        result = enableGuardTx(address(safeWallet));
        require(result == true, "failed enable guard");
        return (address(safeWallet), ownersPK);
    }

    /// function to update Safe Interface
    /// @param safe address of the Safe
    function updateSafeInterface(address safe) public {
        safeWallet = GnosisSafe(payable(address(safe)));
    }

    /// function to get transaction hash of a Safe transaction
    /// @param safeTx Safe transaction
    /// @param nonce Safe nonce
    /// @return bytes32 hash of the transaction
    function createSafeTxHash(Transaction memory safeTx, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        bytes32 txHashed = safeWallet.getTransactionHash(
            safeTx.to,
            safeTx.value,
            safeTx.data,
            safeTx.operation,
            safeTx.safeTxGas,
            safeTx.baseGas,
            safeTx.gasPrice,
            safeTx.gasToken,
            safeTx.refundReceiver,
            nonce
        );

        return txHashed;
    }

    /// function to create a default Safe transaction
    /// @param to address of Safe
    /// @param data data of the transaction
    /// @return Transaction
    function createDefaultTx(address to, bytes memory data)
        public
        pure
        returns (Transaction memory)
    {
        bytes memory emptyData;
        Transaction memory defaultTx = Transaction(
            to,
            0 gwei,
            data,
            Enum.Operation(0),
            0,
            0,
            0,
            address(0),
            address(0),
            emptyData
        );
        return defaultTx;
    }

    /// function to enable module
    /// @param safe address of the Safe
    /// @return bool
    function enableModuleTx(address safe) public returns (bool) {
        /// Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("enableModule(address)", palmeraModuleAddr);

        /// Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to enable guard
    /// @param safe address of the Safe
    /// @return bool
    function enableGuardTx(address safe) public returns (bool) {
        /// Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("setGuard(address)", palmeraGuardAddr);

        /// Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to disable module
    /// @param prevModule address of the previous module
    /// @param safe address of the Safe
    /// @return bool
    function disableModuleTx(address prevModule, address safe)
        public
        returns (bool)
    {
        /// Create enableModule calldata
        bytes memory data = abi.encodeWithSignature(
            "disableModule(address,address)", prevModule, palmeraModuleAddr
        );

        /// Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to disable guard
    /// @param safe address of the Safe
    /// @return bool
    function disableGuardTx(address safe) public returns (bool) {
        /// Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("setGuard(address)", address(0));

        /// Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to execute Safe transaction
    /// @param mockTx Safe transaction
    /// @param signatures signatures of the transaction
    /// @return bool
    function executeSafeTx(Transaction memory mockTx, bytes memory signatures)
        internal
        returns (bool)
    {
        bool result = safeWallet.execTransaction(
            mockTx.to,
            mockTx.value,
            mockTx.data,
            mockTx.operation,
            mockTx.safeTxGas,
            mockTx.baseGas,
            mockTx.gasPrice,
            mockTx.gasToken,
            payable(address(0)),
            signatures
        );

        return result;
    }

    /// function to register organisation
    /// @param orgName name of the organisation
    /// @return bool
    function registerOrgTx(string memory orgName) public returns (bool) {
        /// Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("registerOrg(string)", orgName);

        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);

        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to create a new safe
    /// @param superSafeId super safe
    /// @param name name of the Organisation
    /// @return bool
    function createAddSafeTx(uint256 superSafeId, string memory name)
        public
        returns (bool)
    {
        bytes memory data = abi.encodeWithSignature(
            "addSafe(uint256,string)", superSafeId, name
        );
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to create a new Root Safe
    /// @param newRootSafe address of the new Root Safe
    /// @param name name of the Organisation
    /// @return bool
    function createRootSafeTx(address newRootSafe, string memory name)
        public
        returns (bool)
    {
        bytes memory data = abi.encodeWithSignature(
            "createRootSafe(address,string)", newRootSafe, name
        );
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to remove a safe
    /// @param safeId safe to remove
    /// @return bool
    function createRemoveSafeTx(uint256 safeId) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("removeSafe(uint256)", safeId);
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to remove a whole tree of safes
    /// @return bool
    function createRemoveWholeTreeTx() public returns (bool) {
        bytes memory data = abi.encodeWithSignature("removeWholeTree()");
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to promote a safe to root safe
    /// @param safeId safe to promote
    /// @return bool
    function createPromoteToRootTx(uint256 safeId) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("promoteRoot(uint256)", safeId);
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to set role
    /// @param role role to set
    /// @param user user to set role
    /// @param safeId safe to set role
    /// @param enabled enable or disable role
    /// @return bool
    function createSetRoleTx(
        uint8 role,
        address user,
        uint256 safeId,
        bool enabled
    ) public returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "setRole(uint8,address,uint256,bool)", role, user, safeId, enabled
        );
        /// Create module tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to disconnect a safe
    /// @param safeId safe to disconnect
    /// @return bool
    function createDisconnectSafeTx(uint256 safeId) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("disconnectSafe(uint256)", safeId);
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to execute a transaction on behalf another safe in the organisation, child from the super safe
    /// @param org organisation
    /// @param superSafe super safe
    /// @param targetSafe target safe
    /// @param to receiver
    /// @param value value
    /// @param data data
    /// @param operation operation
    /// @param signaturesExec signatures
    /// @return bool
    function execTransactionOnBehalfTx(
        bytes32 org,
        address superSafe,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bytes memory signaturesExec
    ) public returns (bool) {
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)",
            org,
            superSafe,
            targetSafe,
            to,
            value,
            data,
            operation,
            signaturesExec
        );
        /// Create module safe tx
        Transaction memory mockTx =
            createDefaultTx(palmeraModuleAddr, internalData);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to remove a owner of a safe, into the palmera module
    /// @param prevOwner previous owner
    /// @param ownerRemoved owner to remove
    /// @param threshold threshold
    /// @param targetSafe target safe
    /// @param org organisation
    /// @return bool
    function removeOwnerTx(
        address prevOwner,
        address ownerRemoved,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    ) public returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "removeOwner(address,address,uint256,address,bytes32)",
            prevOwner,
            ownerRemoved,
            threshold,
            targetSafe,
            org
        );
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to add a owner of a safe, into the palmera module
    /// @param ownerAdded owner to add
    /// @param threshold threshold
    /// @param targetSafe target safe
    /// @param org organisation
    /// @return bool
    function addOwnerWithThresholdTx(
        address ownerAdded,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    ) public returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "addOwnerWithThreshold(address,uint256,address,bytes32)",
            ownerAdded,
            threshold,
            targetSafe,
            org
        );
        /// Create module safe tx
        Transaction memory mockTx = createDefaultTx(palmeraModuleAddr, data);
        /// Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    /// function to encode signatures of a Safe transaction to enable a palmera module
    /// @param mockTx Safe transaction
    /// @return bytes signatures
    function encodeSignaturesModuleSafeTx(Transaction memory mockTx)
        public
        view
        returns (bytes memory)
    {
        /// Create encoded tx to be signed
        uint256 nonce = safeWallet.nonce();
        bytes32 enableModuleSafeTx = createSafeTxHash(mockTx, nonce);

        address[] memory owners = safeWallet.getOwners();
        /// Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = safeWallet.getThreshold();

        /// Get pk for the signing threshold
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for (uint256 i; i < threshold; ++i) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures =
            signDigestTx(privateKeySafeOwners, enableModuleSafeTx);

        return signatures;
    }
}
