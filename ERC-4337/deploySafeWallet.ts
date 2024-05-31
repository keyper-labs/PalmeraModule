import { ENTRYPOINT_ADDRESS_V07, createSmartAccountClient } from "permissionless";
import { signerToSafeSmartAccount } from "permissionless/accounts";
import { createPimlicoBundlerClient, createPimlicoPaymasterClient } from "permissionless/clients/pimlico";
import { Hex, createPublicClient, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import { polygon } from "viem/chains";

// Load environment variables
config();

const { PRIVATE_KEY, API_KEY, RPC_URL } = process.env;

if (!PRIVATE_KEY || !API_KEY || !RPC_URL) {
    console.error("One or more environment variables are missing.");
    process.exit(1);
}

const PRIVATEKEY: Hex = `0x${PRIVATE_KEY}`;

async function main() {
    // Create the public client

    // Create the public client
    const publicClient = createPublicClient({
        transport: http(RPC_URL),
    });

    // Create the Paymaster and Bundler clients using the same API key
    const apiUrl = `https://api.pimlico.io/v2/polygon/rpc?apikey=${API_KEY}`;

    const paymasterClient = createPimlicoPaymasterClient({
        transport: http(apiUrl),
        entryPoint: ENTRYPOINT_ADDRESS_V07,
    });

    const pimlicoBundlerClient = createPimlicoBundlerClient({
        transport: http(apiUrl),
        entryPoint: ENTRYPOINT_ADDRESS_V07,
    });

    // Create the signer
    const signer = privateKeyToAccount(PRIVATEKEY);

    // Create the Safe account
    const safeAccount = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        saltNonce: BigInt(143), // Optional
        safeVersion: "1.4.1"
    });

    // Create the smart account client
    const smartAccountClient = createSmartAccountClient({
        account: safeAccount,
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        chain: polygon,
        bundlerTransport: http(apiUrl),
        middleware: {
            sponsorUserOperation: paymasterClient.sponsorUserOperation, // Optional
            gasPrice: async () => (await pimlicoBundlerClient.getUserOperationGasPrice()).fast, // If using Pimlico bundler
        },
    });

    // Example of sending a transaction
    const txHash = await smartAccountClient.sendTransaction({
        to: "0xC9E3Eb820bD40c73d9338Ae721b7a5732cF9a30c",
        value: parseEther("0.1"),
    });

    console.log(`Address of Safe Deployed: ${smartAccountClient.account.address}`);
}

// Execute the main function
main().catch(error => {
    console.error("Error in main function:", error);
    process.exit(1);
});
