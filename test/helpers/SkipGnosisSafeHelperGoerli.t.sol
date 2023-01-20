// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {GnosisSafeProxyFactory} from
    "@safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@safe-contracts/proxies/GnosisSafeProxy.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {IProxyCreationCallback} from
    "@safe-contracts/proxies/IProxyCreationCallback.sol";
import "../../src/SigningUtils.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "../../src/KeyperModule.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import {Random} from "../../libraries/Random.sol";

// Helper contract handling deployment Gnosis Safe contracts
contract SkipGnosisSafeHelperGoerli is
    Test,
    SigningUtils,
    SignDigestHelper,
    SignersHelper
{
    GnosisSafe public gnosisSafe;
    KeyperModule public keyper;
    GnosisSafeProxyFactory public proxyFactory;
    GnosisSafe public gnosisSafeContract;
    GnosisSafeProxy safeProxy;

    address public keyperRolesAddr;
    address private keyperModuleAddr;
    address public keyperGuardAddr;
    address public gnosisMasterCopy;

    uint256 public salt;

    // Create new gnosis safe test environment
    // Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    // Init signers
    // Deploy a new safe proxy
    function setupSafeEnv() public returns (address) {
        start();
        gnosisMasterCopy = address(gnosisSafeContract);
        bytes memory emptyData;
        address gnosisSafeProxy = newSafeProxy(emptyData);
        gnosisSafe = GnosisSafe(payable(gnosisSafeProxy));
        initOnwers(30);

        // Setup gnosis safe with 3 owners, 1 threshold
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        // Update privateKeyOwners used
        updateCount(3);

        gnosisSafe.setup(
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        return address(gnosisSafe);
    }

    // Create new gnosis safe test environment
    // Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    // Init signers
    // Permit create a specific numbers of owners
    // Deploy a new safe proxy
    function setupSeveralSafeEnv(uint256 initOwners) public returns (address) {
        start();
        gnosisMasterCopy = address(gnosisSafeContract);
        salt = Random.randint();
        bytes memory emptyData = abi.encodePacked(salt);
        address gnosisSafeProxy = newSafeProxy(emptyData);
        gnosisSafe = GnosisSafe(payable(gnosisSafeProxy));
        initOnwers(initOwners);

        // Setup gnosis safe with 3 owners, 1 threshold
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        // Update privateKeyOwners used
        updateCount(3);

        gnosisSafe.setup(
            owners,
            uint256(1),
            address(0x0),
            emptyData,
            address(0x0),
            address(0x0),
            uint256(0),
            payable(address(0x0))
        );

        return address(gnosisSafe);
    }

    function start() public {
        proxyFactory =
            GnosisSafeProxyFactory(vm.envAddress("PROXY_FACTORY_ADDRESS"));
        gnosisSafeContract =
            GnosisSafe(payable(vm.envAddress("MASTER_COPY_ADDRESS")));
    }

    function setKeyperRoles(address keyperRoles) public {
        keyperRolesAddr = keyperRoles;
    }

    function setKeyperModule(address keyperModule) public {
        keyperModuleAddr = keyperModule;
        keyper = KeyperModule(keyperModuleAddr);
    }

    function setKeyperGuard(address keyperGuard) public {
        keyperGuardAddr = keyperGuard;
    }

    // Create GnosisSafe with Keyper and send module enabled tx
    function newKeyperSafe(uint256 numberOwners, uint256 threshold)
        public
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
        require(keyperModuleAddr != address(0), "Keyper module not set");
        address[] memory owners = new address[](numberOwners);
        for (uint256 i = 0; i < numberOwners; i++) {
            owners[i] = vm.addr(privateKeyOwners[i + countUsed]);
            countUsed++;
        }
        bytes memory emptyData = abi.encodePacked(Random.randint());
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

        address gnosisSafeProxy = newSafeProxy(initializer);
        gnosisSafe = GnosisSafe(payable(address(gnosisSafeProxy)));

        // Enable module
        bool result = enableModuleTx(address(gnosisSafe));
        require(result == true, "failed enable module");

        // Enable Guard
        result = enableGuardTx(address(gnosisSafe));
        require(result == true, "failed enable guard");
        return address(gnosisSafe);
    }

    function newSafeProxy(bytes memory initializer) public returns (address) {
        uint256 nonce = uint256(keccak256(initializer));
        safeProxy = proxyFactory.createProxyWithNonce(
            address(gnosisSafeContract), initializer, nonce
        );
        return address(safeProxy);
    }

    function testNewKeyperSafe() public {
        setupSafeEnv();
        setKeyperModule(address(0x678));
        newKeyperSafe(4, 2);
        address[] memory owners = gnosisSafe.getOwners();
        assertEq(owners.length, 4);
        assertEq(gnosisSafe.getThreshold(), 2);
    }

    function updateSafeInterface(address safe) public {
        gnosisSafe = GnosisSafe(payable(address(safe)));
    }

    function createSafeTxHash(Transaction memory safeTx, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        bytes32 txHashed = gnosisSafe.getTransactionHash(
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

    function enableModuleTx(address safe) public returns (bool) {
        // Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("enableModule(address)", keyperModuleAddr);

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function enableGuardTx(address safe) public returns (bool) {
        // Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("setGuard(address)", keyperGuardAddr);

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function disableModuleTx(address prevModule, address safe)
        public
        returns (bool)
    {
        // Create enableModule calldata
        bytes memory data = abi.encodeWithSignature(
            "disableModule(address,address)", prevModule, keyperModuleAddr
        );

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function disableGuardTx(address safe) public returns (bool) {
        // Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("setGuard(address)", address(0));

        // Create enable module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function executeSafeTx(Transaction memory mockTx, bytes memory signatures)
        internal
        returns (bool)
    {
        bool result = gnosisSafe.execTransaction(
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

    function registerOrgTx(string memory orgName) public returns (bool) {
        // Create enableModule calldata
        bytes memory data =
            abi.encodeWithSignature("registerOrg(string)", orgName);

        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);

        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createSetRole(
        uint8 role,
        address user,
        uint256 squad,
        bool enabled,
        address safe
    ) public returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "setRole(uint8,address,uint256,bool)", role, user, squad, enabled
        );
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(safe, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createAddSquadTx(uint256 superSafe, string memory name)
        public
        returns (bool)
    {
        bytes memory data =
            abi.encodeWithSignature("addSquad(uint256,string)", superSafe, name);
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createRootSafeTx(address newRootSafe, string memory name)
        public
        returns (bool)
    {
        bytes memory data = abi.encodeWithSignature(
            "createRootSafeSquad(address,string)", newRootSafe, name
        );
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createRemoveSquadTx(uint256 squad) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("removeSquad(uint256)", squad);
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createRemoveWholeTreeTx() public returns (bool) {
        bytes memory data = abi.encodeWithSignature("removeWholeTree()");
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createPromoteToRootTx(uint256 squad) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("promoteRoot(uint256)", squad);
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createDisconnectSafeTx(uint256 squad) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("disconnectSafe(uint256)", squad);
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function execTransactionOnBehalfTx(
        bytes32 org,
        address targetSafe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bytes memory signaturesExec
    ) public returns (bool) {
        bytes memory internalData = abi.encodeWithSignature(
            "execTransactionOnBehalf(bytes32,address,address,uint256,bytes,uint8,bytes)",
            org,
            targetSafe,
            to,
            value,
            data,
            operation,
            signaturesExec
        );
        // Create module safe tx
        Transaction memory mockTx =
            createDefaultTx(keyperModuleAddr, internalData);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

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
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

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
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function encodeSignaturesModuleSafeTx(Transaction memory mockTx)
        public
        view
        returns (bytes memory)
    {
        // Create encoded tx to be signed
        uint256 nonce = gnosisSafe.nonce();
        bytes32 enableModuleSafeTx = createSafeTxHash(mockTx, nonce);

        address[] memory owners = gnosisSafe.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = gnosisSafe.getThreshold();

        // Get pk for the signing threshold
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures =
            signDigestTx(privateKeySafeOwners, enableModuleSafeTx);

        return signatures;
    }

    /// @notice Encode signatures for a keypertx
    function encodeSignaturesKeyperTx(
        address caller,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        // Create encoded tx to be signed
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            caller, safe, to, value, data, operation, nonce
        );

        address[] memory owners = gnosisSafe.getOwners();
        // Order owners
        address[] memory sortedOwners = sortAddresses(owners);
        uint256 threshold = gnosisSafe.getThreshold();

        // Get pk for the signing threshold
        uint256[] memory privateKeySafeOwners = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            privateKeySafeOwners[i] = ownersPK[sortedOwners[i]];
        }

        bytes memory signatures = signDigestTx(privateKeySafeOwners, txHashed);

        return signatures;
    }

    /// @notice Sign keyperTx with invalid signatures (do not belong to any safe owner)
    function encodeInvalidSignaturesKeyperTx(
        address caller,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes memory) {
        // Create encoded tx to be signed
        uint256 nonce = keyper.nonce();
        bytes32 txHashed = keyper.getTransactionHash(
            caller, safe, to, value, data, operation, nonce
        );

        uint256 threshold = gnosisSafe.getThreshold();
        // Get invalid pk for the signing threshold
        uint256[] memory invalidSafeOwnersPK = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            invalidSafeOwnersPK[i] = invalidPrivateKeyOwners[i];
        }

        bytes memory signatures = signDigestTx(invalidSafeOwnersPK, txHashed);

        return signatures;
    }

    function createKeyperTxHash(
        address caller,
        address safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 txHashed = keyper.getTransactionHash(
            caller, safe, to, value, data, operation, nonce
        );
        return txHashed;
    }
}
