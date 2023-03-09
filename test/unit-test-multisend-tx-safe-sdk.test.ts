import Safe from "@safe-global/safe-core-sdk";
import EthersAdapter from "@safe-global/safe-ethers-lib";
import { MetaTransactionData } from "@safe-global/safe-core-sdk-types";
import { toChecksumAddress } from "ethereum-checksum-address";
import { ethers } from "ethers";
import { expect } from "chai";
import { describe, it } from "mocha";
import dotenv from "dotenv";

dotenv.config();

const timeout = async (ms: number) => {
    return new Promise((resolve) => setTimeout(resolve, ms));
};

describe("Multisend transaction", () => {
    let safe: Safe;
    let ethAdapter: EthersAdapter;
    // Define the guard condition and module address
    const guardCondition = toChecksumAddress(`${process.env.KEYPER_GUARD_ADDRESS}`);
    const moduleAddress = toChecksumAddress(`${process.env.KEYPER_MODULE_ADDRESS}`);
    before(async () => {
        // Initialize the Safe client
        const provider = new ethers.providers.JsonRpcProvider(
            `${process.env.GOERLI_RPC_URL}`,
        );
        const signer = new ethers.Wallet(
            `${process.env.PRIVATE_KEY_OWNER_TEST_SAFE_ADDRESS}`,
            provider,
        );

        ethAdapter = new EthersAdapter({
            ethers,
            signerOrProvider: signer,
        });

        safe = await Safe.create({
            ethAdapter,
            safeAddress: `${process.env.TEST_SAFE_ADDRESS}`,
        });

        console.log("Safe address: ", toChecksumAddress(safe.getAddress()));
    });

    it("Validate if connected to the correct network: Goerli", async () => {
        const network = await ethAdapter.getChainId();
        expect(network).to.equal(5);
    });

    it("should execute a multisend transaction enable module/guard", async () => {
        // Create the transactions to enable the guard condition and module
        const enableGuardTx = await safe.createEnableGuardTx(guardCondition);
        const enableModuleTx = await safe.createEnableModuleTx(moduleAddress);

        // Create safe transaction data
        const safeTxData: MetaTransactionData[] = [
            {
                to: safe.getAddress(),
                value: "0",
                data: enableModuleTx.data.data,
            },
            {
                to: safe.getAddress(),
                value: "0",
                data: enableGuardTx.data.data,
            },
        ];

        // Create the Multisend transaction
        const multisendTx = await safe.createTransaction({
            safeTransactionData: safeTxData,
        });

        // Execute the Multisend transaction
        const txResponse = await safe.executeTransaction(multisendTx, {
            gasLimit: 500000,
        });

        await txResponse.transactionResponse?.wait();

        // Verify if the Safe is already enabled
        const isGuardEnabled = toChecksumAddress(await safe.getGuard());
        const isModuleEnabled = await safe.isModuleEnabled(moduleAddress);
        // Test if the guard condition and module are enabled
        expect(isGuardEnabled).to.be.equal(guardCondition);
        expect(isModuleEnabled).to.be.true;

        await timeout(60000);
    });

    it("should execute a multisend transaction disable module/guard", async () => {
        // Rollback the changes
        const disableGuardTx = await safe.createDisableGuardTx();
        const disableModuleTx = await safe.createDisableModuleTx(moduleAddress);

        const safeTxData2: MetaTransactionData[] = [
            {
                to: safe.getAddress(),
                value: "0",
                data: disableModuleTx.data.data,
            },
            {
                to: safe.getAddress(),
                value: "0",
                data: disableGuardTx.data.data,
            },
        ];

        const multisendTx2 = await safe.createTransaction({
            safeTransactionData: safeTxData2,
        });

        const txResponse2 = await safe.executeTransaction(multisendTx2, {
            gasLimit: 500000,
        });

        await txResponse2.transactionResponse?.wait();

        // Verify if the Safe is already enabled
        const isGuardDisabled = toChecksumAddress(await safe.getGuard());
        const isModuleDisabled = await safe.isModuleEnabled(moduleAddress);

        // Test if the guard condition and module are disabled
        expect(isGuardDisabled).to.be.equal(
            "0x0000000000000000000000000000000000000000",
        );
        expect(isModuleDisabled).to.be.false;
    });
});
