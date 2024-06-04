import {
    ENTRYPOINT_ADDRESS_V07,
} from "permissionless";
import {
    signerToSafeSmartAccount,
} from "permissionless/accounts";
import {
    Hex,
    CallReturnType,
    parseEther,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import Safe from '@safe-global/protocol-kit';
import { snooze, smartAccountClient, publicClient, apiUrl, activateModuleAndGuard, registerOrg, createAddSafe, getOrgHashBySafe, getTransactionHash, execTransactionOnBehalf, pimlicoBundlerClient } from "./utils/utils";
import { pimlicoBundlerActions } from "permissionless/actions/pimlico";

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


async function main() {
    console.log("entrypoint", ENTRYPOINT_ADDRESS_V07);

    // Create the signer
    const signer = privateKeyToAccount(PRIVATEKEY);

    // Create the Safe account
    const RootSafe = await signerToSafeSmartAccount(publicClient(RPC_URL!!), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(351),
    });

    const rootSafeClient = smartAccountClient(RootSafe);

    console.log("Root Safe Client Address: ", rootSafeClient.account.address);

    // transfer 0.3 matic to the Root Safe
    const tx = await rootSafeClient.sendTransaction({
        to: RootSafe.address,
        value: parseEther("0.3"),
    });

    console.log("Transaction hash Root Safe: ", tx);

    const RootSafeProcolKit = await Safe.init({
        provider: RPC_URL!!,
        signer: PRIVATEKEY,
        isL1SafeSingleton: false,
        safeAddress: RootSafe.address,
    });


    const superSafe = await signerToSafeSmartAccount(publicClient(apiUrl(RPC_URL!!)), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(352),
    });

    // transfer 0.1 matic to the Super Safe
    const tx2 = await rootSafeClient.sendTransaction({
        to: superSafe.address,
        value: parseEther("0.1"),
    });

    console.log("Transaction hash Super Safe: ", tx2);

    const childSafe = await signerToSafeSmartAccount(publicClient(apiUrl(RPC_URL!!)), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(353),
    });

    // transfer 0.1 matic to the Child Safe
    const tx3 = await rootSafeClient.sendTransaction({
        to: childSafe.address,
        value: parseEther("0.1"),
    });

    console.log("Transaction hash Child Safe: ", tx3);

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
    await registerOrg(RootSafe, "MyOrg2");
    await snooze(5000);
    // Add Safes to the organization Under Root Safe id: 1
    await createAddSafe(superSafe, 1, "Level 1 Safe v2");
    await snooze(5000);
    // Add Safes to the organization Under SuperSafe Safe id: 2
    await createAddSafe(childSafe, 2, "Level 2 Safe v2");
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
function getNonce(): CallReturnType | PromiseLike<CallReturnType> {
    throw new Error("Function not implemented.");
}

