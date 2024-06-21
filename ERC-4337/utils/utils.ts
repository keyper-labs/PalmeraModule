import {
    ENTRYPOINT_ADDRESS_V07,
    createSmartAccountClient,
} from "permissionless";
import {
    SafeSmartAccount,
} from "permissionless/accounts";
import {
    createPimlicoBundlerClient,
    createPimlicoPaymasterClient,
} from "permissionless/clients/pimlico";
import {
    Hex,
    HttpTransport,
    createPublicClient,
    http,
    encodeFunctionData,
    CallReturnType,
} from "viem";
import { config } from "dotenv";
import { polygon } from "viem/chains";
import { palmeraModuleAbi, safeAbi } from "../abi/palmeraModule";
import { MetaTransactionData, SafeSignature } from '@safe-global/safe-core-sdk-types';
import { ENTRYPOINT_ADDRESS_V07_TYPE } from "permissionless/types";
import Safe from '@safe-global/protocol-kit';

// Load environment variables
config();

const {
    PRIVATE_KEY,
    API_KEY,
    RPC_URL,
    PALMERA_MODULE_ADDRESS,
} = process.env;

if (!PRIVATE_KEY || !API_KEY || !RPC_URL) {
    console.error("One or more environment variables are missing.");
    process.exit(1);
}

const PALMERA_MODULE: Hex = `0x${PALMERA_MODULE_ADDRESS?.slice(2)}`;

export const snooze = (ms: number) =>
    new Promise((resolve) => setTimeout(resolve, ms));

// Create the public client
export const publicClient = (RPC_URL: string) => createPublicClient({ transport: http(RPC_URL) });

// Create the Paymaster and Bundler clients using the same API key
export const apiUrl = (API_KEY: string) => `https://api.pimlico.io/v2/polygon/rpc?apikey=${API_KEY}`;

// Create the Paymaster clients
const paymasterClient = (API_KEY: string, ENTRYPOINT_ADDRESS_V07: any) => createPimlicoPaymasterClient({
    transport: http(apiUrl(API_KEY)),
    entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create the Bundler clients
export const pimlicoBundlerClient = (API_KEY: string, ENTRYPOINT_ADDRESS_V07: any) => createPimlicoBundlerClient({
    transport: http(apiUrl(API_KEY)),
    entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create the Smart Account client
export const smartAccountClient = (
    safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>) => {
    return createSmartAccountClient({
        account: safe,
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        chain: polygon,
        bundlerTransport: http(apiUrl(API_KEY)),
        middleware: {
            sponsorUserOperation: paymasterClient(API_KEY, ENTRYPOINT_ADDRESS_V07).sponsorUserOperation,
            gasPrice: async () =>
                (await pimlicoBundlerClient(API_KEY, ENTRYPOINT_ADDRESS_V07).getUserOperationGasPrice()).fast,
        },
    });
};

// Activate Palmera Module and Guard
export const activateModuleAndGuard = async (safeAccount: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, moduleAddress: string, guardAddress: string) => {
    const enableModuleData: Hex = encodeFunctionData({
        abi: safeAbi,
        functionName: "enableModule",
        args: [moduleAddress]
    });
    const enableGuardData: Hex = encodeFunctionData({
        abi: safeAbi,
        functionName: "setGuard",
        args: [guardAddress]
    });

    // Create the smart account client
    const SmartAccountClient = smartAccountClient(safeAccount);

    try {
        const txHash3 = await SmartAccountClient.sendTransaction({
            to: safeAccount.address,
            data: enableModuleData,
            value: BigInt(0),
        });

        console.log(`Transaction hash Enable Module in Safe ${safeAccount.address}: https://polygonscan.com/tx/${txHash3}`);
    } catch (error) {
        console.error("Error enabling module:", error);
        return;
    }

    await snooze(5000);

    try {
        const txHash4 = await SmartAccountClient.sendTransaction({
            to: safeAccount.address,
            data: enableGuardData,
            value: BigInt(0),
        });

        console.log(`Transaction hash Enable Guard in Safe ${safeAccount.address}: https://polygonscan.com/tx/${txHash4}`);
    } catch (error) {
        console.error("Error enabling guard:", error);
    }
};

// Register organization and create additional Safes
export const registerOrg = async (safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, orgName: string) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "registerOrg",
        args: [orgName]
    });
    // Create the smart account client
    const SmartAccountClient = smartAccountClient(safe);
    const txHash = await SmartAccountClient.sendTransaction({
        to: PALMERA_MODULE,
        data: data,
        value: BigInt(0)
    });
    console.log(`Transaction hash Register Organization of Safe ${safe.address}: https://polygonscan.com/tx/${txHash}`);
};

// Add Safe to an On-chain Organization or SuperSafe into Palmera Module
export const createAddSafe = async (safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, superSafe: number, name: string) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "addSafe",
        args: [superSafe, name]
    });
    // Create the smart account client
    const SmartAccountClient = smartAccountClient(safe);
    const txHash = await SmartAccountClient.sendTransaction({
        to: PALMERA_MODULE,
        data: data,
        value: BigInt(0)
    });
    console.log(`Transaction hash Add Safe Address ${safe.address} to SuperSafe Id ${superSafe} with name ${name}: https://polygonscan.com/tx/${txHash}`);
};

// Method to get Org hash by Safe address
export const getOrgHashBySafe = async (safeAddress: Hex) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "getOrgHashBySafe",
        args: [safeAddress],
    });
    const result = await publicClient(RPC_URL!!).call({
        to: PALMERA_MODULE,
        data: data,
        value: BigInt(0),
    });
    return result;
};

// Method to get Safe Id by Safe address
export const getSafeIdBySafe = async (orgHash: Hex, safeAddress: Hex) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "getSafeIdBySafe",
        args: [orgHash, safeAddress],
    });
    const result: CallReturnType = await publicClient(RPC_URL!!).call({
        to: PALMERA_MODULE,
        data: data,
        value: BigInt(0),
    });
    return result;
};

// get nonce from Palmera Module
export const getNonce = async (org: Hex) => {
    const internalData: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "nonce",
        args: [org],
    });
    const result = await publicClient(RPC_URL!!).call({
        to: PALMERA_MODULE,
        data: internalData,
        value: BigInt(0),
    });
    return result;
};

// getTransactionHash from Palmera Module
export const getTransactionHash = async (
    org: Hex,
    superSafe: string,
    targetSafe: string,
    to: string,
    value: BigInt,
    data: Hex,
    operation: number,
    nonce: number,
) => {
    console.log("getTransactionHash args: ",
        org,
        superSafe,
        targetSafe,
        to,
        value,
        data,
        operation,
        nonce,);
    const internalData: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "getTransactionHash",
        args: [
            org,
            superSafe,
            targetSafe,
            to,
            value,
            data,
            operation,
            nonce,
        ],
    });
    const result = await publicClient(RPC_URL!!).call({
        to: PALMERA_MODULE,
        data: internalData,
        value: BigInt(0),
    });
    return result;
};


// Execute transaction on behalf of the lowest-level Safe
export const execTransactionOnBehalf = async (
    org: Hex,
    superSafe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>,
    targetSafe: string,
    to: string,
    value: BigInt,
    data: Hex,
    operation: number,
    signaturesExec: SafeSignature["data"],
) => {
    const internalData: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "execTransactionOnBehalf",
        args: [
            org,
            superSafe.address,
            targetSafe,
            to,
            value,
            data,
            operation,
            signaturesExec,
        ],
    });
    const SmartAccountClient = smartAccountClient(superSafe);
    const txHash = await SmartAccountClient.sendTransaction({
        to: PALMERA_MODULE,
        data: internalData,
        value: BigInt(0),
    });
    console.log(
        `Transaction hash Execute Transaction on Behalf of Root/Super Safe ${superSafe.address} over Target Safe ${targetSafe}: https://polygonscan.com/tx/${txHash}`,
    );
};