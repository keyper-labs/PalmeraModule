import { ENTRYPOINT_ADDRESS_V07, createSmartAccountClient } from "permissionless";
import { SafeSmartAccount, signerToSafeSmartAccount } from "permissionless/accounts";
import { createPimlicoBundlerClient, createPimlicoPaymasterClient } from "permissionless/clients/pimlico";
import { CallReturnType, Hex, HttpTransport, createPublicClient, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import { polygon } from "viem/chains";

// Load environment variables
config();

const { PK, API_KEY, RPC_URL } = process.env;

if (!PK || !API_KEY || !RPC_URL) {
    console.error("One or more environment variables are missing.");
    process.exit(1);
}

const PRIVATE_KEY: Hex = `0x${PK}`;

const snooze = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
    // Create the public client
    const publicClient = createPublicClient({ transport: http(RPC_URL) });

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
    const signer = privateKeyToAccount(PRIVATE_KEY);

    // Create the Safe account
    const RootSafe = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0x62f1d978361c39b42DBdb2Bb3f68A5Bb587e5eAa"
    });

    // Create the smart account client
    const smartAccountClient = createSmartAccountClient({
        account: RootSafe,
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        chain: polygon,
        bundlerTransport: http(apiUrl),
        middleware: {
            sponsorUserOperation: paymasterClient.sponsorUserOperation,
            gasPrice: async () => (await pimlicoBundlerClient.getUserOperationGasPrice()).fast,
        },
    });

    console.log(`Safe Address: ${RootSafe.address}`);
    console.log(`Smart Account Client: ${smartAccountClient.account.address}`);

    await snooze(5000);

    const safe1 = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0xEF08f146bFbA20f7216c4f0C20B31A66E788Ad59"
    });
    const safe2 = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0xd994CBeeBD1020BbF4A48E8BeC8d803e988E562f"
    });

    // Activate Palmera Module and Guard
    // TODO: add Safe Transaction Data / Interface
    const activateModuleAndGuard = async (safeAccount: SafeSmartAccount<"0x0000000071727De22E5E9d8BAf0edAc6f37da032", HttpTransport, undefined>, moduleAddress: string, guardAddress: string) => {
        const enableModuleData: Hex = `0x${Buffer.from("enableModule(address)").toString("hex")}${moduleAddress.slice(2).padStart(64, '0')}`;
        const enableGuardData: Hex = `0x${Buffer.from("setGuard(address)").toString("hex")}${guardAddress.slice(2).padStart(64, '0')}`;

        console.log(`Enable Module Data: ${enableModuleData}`);
        console.log(`Enable Guard Data: ${enableGuardData}`);

        try {
            const txHash3 = await smartAccountClient.sendTransaction({
                to: safeAccount.address,
                data: enableModuleData,
                value: BigInt(0),
            });

            console.log(`Transaction hash Enable Module: ${txHash3}`);
        } catch (error) {
            console.error("Error enabling module:", error);
            return;
        }

        await snooze(5000);

        try {
            const txHash4 = await smartAccountClient.sendTransaction({
                to: safeAccount.address,
                data: enableGuardData,
                value: BigInt(0),
            });

            console.log(`Transaction hash Enable Guard: ${txHash4}`);
        } catch (error) {
            console.error("Error enabling guard:", error);
        }
    };

    await activateModuleAndGuard(RootSafe, "0xace3fdef3ad94fba51d2393138367c6f012a7aa1", "0x03a1405d58a9606ec57ac7d6e15f62bb66bfb3d8");
    await snooze(5000);
    await activateModuleAndGuard(safe1, "0xace3fdef3ad94fba51d2393138367c6f012a7aa1", "0x03a1405d58a9606ec57ac7d6e15f62bb66bfb3d8");
    await snooze(5000);
    await activateModuleAndGuard(safe2, "0xace3fdef3ad94fba51d2393138367c6f012a7aa1", "0x03a1405d58a9606ec57ac7d6e15f62bb66bfb3d8");

    // Register organization and create additional Safes
    const registerOrg = async (orgName: string) => {
        const data: Hex = `0x${Buffer.from("registerOrg(string)").toString("hex")}${Buffer.from(orgName).toString("hex").padEnd(64, '0')}`;
        const txHash = await smartAccountClient.sendTransaction({
            to: "0xad0211cb2c3bad9b211b46f49dab65ce2d1357f3",
            data: data,
            value: BigInt(0)
        });
        console.log(`Transaction hash Register Organization: ${txHash}`);
    };

    const createAddSafe = async (safe: SafeSmartAccount<"0x0000000071727De22E5E9d8BAf0edAc6f37da032", HttpTransport, undefined>, superSafe: number, name: string) => {
        const data: Hex = `0x${Buffer.from("addSafe(uint256,string)").toString("hex")}${superSafe.toString(16).padStart(64, '0')}${Buffer.from(name).toString("hex").padEnd(64, '0')}`;
        // Create the smart account client
        const SmartAccountClient = createSmartAccountClient({
            account: safe,
            entryPoint: ENTRYPOINT_ADDRESS_V07,
            chain: polygon,
            bundlerTransport: http(apiUrl),
            middleware: {
                sponsorUserOperation: paymasterClient.sponsorUserOperation,
                gasPrice: async () => (await pimlicoBundlerClient.getUserOperationGasPrice()).fast,
            },
        });
        const txHash = await SmartAccountClient.sendTransaction({
            to: "0xace3fdef3ad94fba51d2393138367c6f012a7aa1",
            data: data,
            value: BigInt(0)
        });
        console.log(`Transaction hash Add Safe to SuperSafe Id ${superSafe} with name ${name}: ${txHash}`);
    };

    await registerOrg("MyOrg");
    await snooze(5000);
    await createAddSafe(safe1, 1, "Level 1 Safe");
    await snooze(5000);
    await createAddSafe(safe2, 2, "Level 2 Safe");
    await snooze(5000);

    // Method to get Org hash by Safe address
    const getOrgHashBySafe = async (safeAddress: Hex) => {
        const data: Hex = `0x${Buffer.from("getOrgHashBySafe(address)").toString("hex")}${safeAddress.slice(2).padStart(64, '0')}`;
        const result = await publicClient.call({
            to: "0xace3fdef3ad94fba51d2393138367c6f012a7aa1",
            data: data,
        });
        return result;
    };

    const orgHash: CallReturnType = await getOrgHashBySafe(safe2.address);

    console.log(`Organization Hash: ${orgHash.data}`);

    // Execute transaction on behalf of the lowest-level Safe
    const execTransactionOnBehalf = async (org: Hex, superSafe: string, targetSafe: string, to: string, value: BigInt, data: Hex, operation: number, signaturesExec: Hex) => {
        const internalData: Hex = `0x${Buffer.from("execTransactionOnBehalf(bytes32,address,address,address,uint256,bytes,uint8,bytes)").toString("hex")}${Buffer.from(org).toString("hex").padEnd(64, '0')}${superSafe.slice(2).padStart(64, '0')}${targetSafe.slice(2).padStart(64, '0')}${to.slice(2).padStart(64, '0')}${value.toString(16).padStart(64, '0')}${Buffer.from(data).toString("hex").padEnd(64, '0')}${operation.toString(16).padStart(2, '0')}${Buffer.from(signaturesExec).toString("hex").padEnd(64, '0')}`;
        const txHash = await smartAccountClient.sendTransaction({
            to: "0xace3fdef3ad94fba51d2393138367c6f012a7aa1",
            data: internalData,
            value: BigInt(0)
        });
        console.log(`Transaction hash Execute Transaction on Behalf of Safe: ${txHash}`);
    };

    await execTransactionOnBehalf(orgHash.data!!, RootSafe.address, safe2.address, "0xd41014BDA7680abE19034CbDA78b3807e51Ff2e8", parseEther("0.1"), "0x", 0, "0x");
    await snooze(5000);

    console.log(`Root Safe Address: ${RootSafe.address}`);
    console.log(`Second Safe Address: ${safe1.address}`);
    console.log(`Third Safe Address: ${safe2.address}`);
}

// Execute the main function
main().catch(error => {
    console.error("Error in main function:", error);
    process.exit(1);
});
