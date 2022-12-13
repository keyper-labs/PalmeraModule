pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/SigningUtils.sol";
import "./SignDigestHelper.t.sol";
import "./SignersHelper.t.sol";
import "../../script/DeploySafeFactory.t.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";
import {Constants} from "../../libraries/Constants.sol";

// Helper contract handling deployment Gnosis Safe contracts
contract GnosisSafeHelper is
    Test,
    SigningUtils,
    SignDigestHelper,
    SignersHelper
{
    GnosisSafe public gnosisSafe;
    DeploySafeFactory public safeFactory;

    address public keyperRoles;
    address private keyperModuleAddr;
    address public gnosisMasterCopy;

    uint256 public salt;

    function setKeyperRoles(address _keyperRoles) public {
        keyperRoles = _keyperRoles;
    }

    // Create new gnosis safe test environment
    // Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    // Init signers
    // Deploy a new safe proxy
    function setupSafeEnv() public returns (address) {
        safeFactory = new DeploySafeFactory();
        safeFactory.run();
        gnosisMasterCopy = address(safeFactory.gnosisSafeContract());
        bytes memory emptyData;
        address gnosisSafeProxy = safeFactory.newSafeProxy(emptyData);
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
    // Deploy a new safe proxy
    function setupSeveralSafeEnv() public returns (address) {
        safeFactory = new DeploySafeFactory();
        safeFactory.run();
        gnosisMasterCopy = address(safeFactory.gnosisSafeContract());
        salt++;
        bytes memory emptyData = abi.encodePacked(salt);
        address gnosisSafeProxy = safeFactory.newSafeProxy(emptyData);
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

    function setKeyperModule(address keyperModule) public {
        keyperModuleAddr = keyperModule;
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

        address gnosisSafeProxy = safeFactory.newSafeProxy(initializer);
        gnosisSafe = GnosisSafe(payable(address(gnosisSafeProxy)));

        // Enable module
        bool result = enableModuleTx(address(gnosisSafe));
        require(result == true, "failed enable module");
        return address(gnosisSafe);
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

    function createAddGroupTx(uint256 superSafe, string memory name)
        public
        returns (bool)
    {
        bytes memory data =
            abi.encodeWithSignature("addGroup(uint256,string)", superSafe, name);
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
            "createRootSafeGroup(address,string)", newRootSafe, name
        );
        // Create module safe tx
        Transaction memory mockTx = createDefaultTx(keyperModuleAddr, data);
        // Sign tx
        bytes memory signatures = encodeSignaturesModuleSafeTx(mockTx);
        bool result = executeSafeTx(mockTx, signatures);
        return result;
    }

    function createRemoveGroupTx(uint256 group) public returns (bool) {
        bytes memory data =
            abi.encodeWithSignature("removeGroup(uint256)", group);
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
        bytes calldata data,
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

    function encodeSignaturesModuleSafeTx(Transaction memory mockTx)
        public
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
}
