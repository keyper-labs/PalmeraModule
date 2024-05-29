// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "./SafeHelper.t.sol";
import "./PalmeraModuleHelper.t.sol";
import {PalmeraModule} from "../../src/PalmeraModule.sol";

/// @notice Helper contract handling deployment Safe contracts
/// @custom:security-contact general@palmeradao.xyz
contract SkipSafeHelper is SafeHelper, PalmeraModuleHelper {
    SafeProxyFactory public proxyFactory;
    Safe public safeContract;
    SafeProxy safeProxy;
    uint256 nonce;

    // Create new safe test environment
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
        safeMasterCopy = address(safeContract);
        salt = Random.randint();
        bytes memory emptyData = abi.encodePacked(salt);
        address safeWalletProxy = newSafeProxy(emptyData);
        safeWallet = Safe(payable(safeWalletProxy));
        initOnwers(initOwners);

        // Setup safe with 3 owners, 1 threshold
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(privateKeyOwners[0]);
        owners[1] = vm.addr(privateKeyOwners[1]);
        owners[2] = vm.addr(privateKeyOwners[2]);
        // Update privateKeyOwners used
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

    /// @notice Setup the environment for the test
    function start() public {
        proxyFactory = SafeProxyFactory(vm.envAddress("PROXY_FACTORY_ADDRESS"));
        safeContract = Safe(payable(vm.envAddress("MASTER_COPY_ADDRESS")));
    }

    /// function to set the PalmeraModule address
    /// @param palmeraModule address of the PalmeraModule
    function setPalmeraModule(address palmeraModule) public override {
        palmeraModuleAddr = palmeraModule;
        palmera = PalmeraModule(payable(palmeraModuleAddr));
    }

    /// function to create a new Palmera Safe
    /// @param numberOwners amount of owners to initialize
    /// @param threshold amount of signatures required to execute a transaction
    /// @return address of the new Palmera Safe
    function newPalmeraSafe(uint256 numberOwners, uint256 threshold)
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
        require(palmeraModuleAddr != address(0), "Palmera module not set");
        address[] memory owners = new address[](numberOwners);
        for (uint256 i; i < numberOwners; ++i) {
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

        address safeWalletProxy = newSafeProxy(initializer);
        safeWallet = Safe(payable(address(safeWalletProxy)));

        // Enable module
        bool result = enableModuleTx(address(safeWallet));
        require(result == true, "failed enable module");

        // Enable Guard
        result = enableGuardTx(address(safeWallet));
        require(result == true, "failed enable guard");
        return address(safeWallet);
    }

    /// function to create a new Safe Proxy
    /// @param initializer bytes data to initialize the Safe
    /// @return address of the new Safe Proxy
    function newSafeProxy(bytes memory initializer) public returns (address) {
        safeProxy = proxyFactory.createProxyWithNonce(
            address(safeContract), initializer, nonce
        );
        nonce++;
        return address(safeProxy);
    }
}
