import {
    ENTRYPOINT_ADDRESS_V07,
    createSmartAccountClient,
} from "permissionless";
import {
    SafeSmartAccount,
    signerToSafeSmartAccount,
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
    parseEther,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import { polygon } from "viem/chains";
import { palmeraModuleAbi, safeAbi } from "./abi/palmeraModule";
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
    PALMERA_GUARD_ADDRESS,
} = process.env;

if (!PRIVATE_KEY || !API_KEY || !RPC_URL) {
    console.error("One or more environment variables are missing.");
    process.exit(1);
}

const PRIVATEKEY: Hex = `0x${PRIVATE_KEY}`;
const PALMERA_MODULE: Hex = `0x${PALMERA_MODULE_ADDRESS?.slice(2)}`;
const PALMERA_GUARD: Hex = `0x${PALMERA_GUARD_ADDRESS?.slice(2)}`;

const snooze = (ms: number) =>
    new Promise((resolve) => setTimeout(resolve, ms));

// Create the public client
const publicClient = createPublicClient({ transport: http(RPC_URL) });

// Create the Paymaster and Bundler clients using the same API key
const apiUrl = `https://api.pimlico.io/v2/polygon/rpc?apikey=${API_KEY}`;

// Create the Paymaster clients
const paymasterClient = createPimlicoPaymasterClient({
    transport: http(apiUrl),
    entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create the Bundler clients
const pimlicoBundlerClient = createPimlicoBundlerClient({
    transport: http(apiUrl),
    entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create the Smart Account client
const smartAccountClient = (
    safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>) => {
    return createSmartAccountClient({
        account: safe,
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        chain: polygon,
        bundlerTransport: http(apiUrl),
        middleware: {
            sponsorUserOperation: paymasterClient.sponsorUserOperation,
            gasPrice: async () =>
                (await pimlicoBundlerClient.getUserOperationGasPrice()).fast,
        },
    });
};

// Activate Palmera Module and Guard
const activateModuleAndGuard = async (safeAccount: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, moduleAddress: string, guardAddress: string) => {
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
const registerOrg = async (safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, orgName: string) => {
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
const createAddSafe = async (safe: SafeSmartAccount<ENTRYPOINT_ADDRESS_V07_TYPE, HttpTransport, undefined>, superSafe: number, name: string) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "addSafe",
        args: [superSafe, name]
    });
    // Create the smart account client
    const SmartAccountClient = smartAccountClient(safe);
    const txHash = await SmartAccountClient.sendTransaction({
        to: "0xace3fdef3ad94fba51d2393138367c6f012a7aa1",
        data: data,
        value: BigInt(0)
    });
    console.log(`Transaction hash Add Safe Address ${safe.address} to SuperSafe Id ${superSafe} with name ${name}: https://polygonscan.com/tx/${txHash}`);
};

// Method to get Org hash by Safe address
const getOrgHashBySafe = async (safeAddress: Hex) => {
    const data: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "getOrgHashBySafe",
        args: [safeAddress],
    });
    const result = await publicClient.call({
        to: PALMERA_MODULE,
        data: data,
        value: BigInt(0),
    });
    return result;
};

// get nonce from Palmera Module
const getNonce = async () => {
    const internalData: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "nonce",
        args: [],
    });
    const result = await publicClient.call({
        to: PALMERA_MODULE,
        data: internalData,
        value: BigInt(0),
    });
    return result;
};

// getTransactionHash from Palmera Module
const getTransactionHash = async (
    org: Hex,
    superSafe: SafeSmartAccount<
        `${ENTRYPOINT_ADDRESS_V07_TYPE}`,
        HttpTransport,
        undefined
    >,
    targetSafe: string,
    to: string,
    value: BigInt,
    data: Hex,
    operation: number,
    nonce: number,
) => {
    const internalData: Hex = encodeFunctionData({
        abi: palmeraModuleAbi,
        functionName: "getTransactionHash",
        args: [
            org,
            superSafe.address,
            targetSafe,
            to,
            value,
            data,
            operation,
            nonce,
        ],
    });
    const result = await publicClient.call({
        to: PALMERA_MODULE,
        data: internalData,
        value: BigInt(0),
    });
    return result;
};


// Execute transaction on behalf of the lowest-level Safe
const execTransactionOnBehalf = async (
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

async function main() {
    console.log("entrypoint", ENTRYPOINT_ADDRESS_V07);

    // Create the signer
    const signer = privateKeyToAccount(PRIVATEKEY);

    // Create the Safe account
    const RootSafe = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0x62f1d978361c39b42DBdb2Bb3f68A5Bb587e5eAa",
    });

    const RootSafeProcolKit = await Safe.init({
        provider: RPC_URL!!,
        signer: PRIVATEKEY,
        isL1SafeSingleton: false,
        safeAddress: "0x62f1d978361c39b42DBdb2Bb3f68A5Bb587e5eAa",
    });

    console.log("Smart Account Client, Account Address: ", smartAccountClient(RootSafe).account.address);

    const superSafe = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0xEF08f146bFbA20f7216c4f0C20B31A66E788Ad59",
    });
    const childSafe = await signerToSafeSmartAccount(publicClient, {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        address: "0xd994CBeeBD1020BbF4A48E8BeC8d803e988E562f",
    });

    console.log(`Root Safe Address: ${RootSafe.address}`);
    console.log(`Second Safe Address: ${superSafe.address}`);
    console.log(`Third Safe Address: ${childSafe.address}`);

    // Enable Palmera Module and Guard in Root Safe, superSafe and childSafe
    await activateModuleAndGuard(RootSafe, PALMERA_MODULE, PALMERA_GUARD);
    await snooze(5000);
    await activateModuleAndGuard(superSafe, PALMERA_MODULE, PALMERA_GUARD);
    await snooze(5000);
    await activateModuleAndGuard(childSafe, PALMERA_MODULE, PALMERA_GUARD);

    // Register organization
    await registerOrg(RootSafe, "MyOrg");
    await snooze(5000);
    // Add Safes to the organization Under Root Safe id: 1
    await createAddSafe(superSafe, 1, "Level 1 Safe");
    await snooze(5000);
    // Add Safes to the organization Under SuperSafe Safe id: 2
    await createAddSafe(childSafe, 2, "Level 2 Safe");
    await snooze(5000);

    const orgHash: CallReturnType = await getOrgHashBySafe(RootSafe.address);
    const orgHash1: CallReturnType = await getOrgHashBySafe(superSafe.address);
    const orgHash2: CallReturnType = await getOrgHashBySafe(childSafe.address);

    console.log(`Organization Hash of RootSafe: ${orgHash.data}`);
    console.log(`Organization Hash of superSafe: ${orgHash1.data}`);
    console.log(`Organization Hash of childSafe: ${orgHash2.data}`);

    // Get nonce from Palmera Module
    const nonce: CallReturnType = await getNonce();
    console.log(`Nonce: ${nonce.data}`);


    const txHash: CallReturnType = await getTransactionHash(
        orgHash.data!!,
        RootSafe,
        childSafe.address,
        "0xd41014BDA7680abE19034CbDA78b3807e51Ff2e8",
        parseEther("0.1"),
        "0x",
        0,
        parseInt(nonce.data!!),
    );
    console.log(`Transaction hash by ExecutionOnBeHalf: ${txHash.data}`);

    // Sign the transaction hash
    const sign = await RootSafeProcolKit.signHash(txHash.data!!);
    console.log(`Sign: ${sign.data}`);
    // Execute transaction on behalf of RooSafe over childSafe
    await execTransactionOnBehalf(
        orgHash.data!!,
        RootSafe,
        childSafe.address,
        "0xd41014BDA7680abE19034CbDA78b3807e51Ff2e8",
        parseEther("0.1"),
        "0x",
        0,
        sign.data,
    );
}

// Execute the main function
main().catch((error) => {
    console.error("Error in main function:", error);
    process.exit(1);
});
