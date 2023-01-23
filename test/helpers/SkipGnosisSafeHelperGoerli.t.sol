// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./GnosisSafeHelper.t.sol";
import {KeyperModule} from "../../src/KeyperModule.sol";
// Helper contract handling deployment Gnosis Safe contracts

contract SkipGnosisSafeHelperGoerli is GnosisSafeHelper {
    KeyperModule public keyper;
    GnosisSafeProxyFactory public proxyFactory;
    GnosisSafe public gnosisSafeContract;
    GnosisSafeProxy safeProxy;

    // Create new gnosis safe test environment
    // Deploy main safe contracts (GnosisSafeProxyFactory, GnosisSafe mastercopy)
    // Init signers
    // Permit create a specific numbers of owners
    // Deploy a new safe proxy
    function setupSeveralSafeEnv(uint256 initOwners)
        public
        override
        returns (address)
    {
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

    function setKeyperModule(address keyperModule) public override {
        keyperModuleAddr = keyperModule;
        keyper = KeyperModule(keyperModuleAddr);
    }

    function newKeyperSafe(uint256 numberOwners, uint256 threshold)
        public
        override
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
