import { ENTRYPOINT_ADDRESS_V07 } from "permissionless";
import { signerToSafeSmartAccount } from "permissionless/accounts";
import { Hex, CallReturnType, parseEther, createWalletClient, http } from "viem";
import { polygon } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import Safe from "@safe-global/protocol-kit";
import {
    snooze,
    smartAccountClient,
    publicClient,
    activateModuleAndGuard,
    registerOrg,
    createAddSafe,
    getOrgHashBySafe,
    getTransactionHash,
    execTransactionOnBehalf,
    getNonce,
} from "./utils/utils";
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

// Main function
// To create a Safe with SDK permissionless, you need to create a Safe account and then use the Safe account to create a Smart Account client
// The Smart Account client is used to send transactions
// th script create 3 Safes, Root Safe, Super Safe and Child Safe
// After registering the organization, the script adds the Super Safe and Child Safe to the Root Safe organization
// Getting Org Hash, and Transaction Hash
// Use RootSafe Instance of Protocol Kit to sign the transaction hash
// Execute transaction on behalf of RooSafe over childSafe
// TODO: Must be change the salt nonce for each safe, in case you need to run the script again!!
async function main() {
    console.log("entrypoint", ENTRYPOINT_ADDRESS_V07);

    // Create the signer
    const signer = privateKeyToAccount(PRIVATEKEY);

    // Create the Safe account
    const RootSafe = await signerToSafeSmartAccount(publicClient(RPC_URL!!), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(312),
    });

    const rootSafeClient = smartAccountClient(RootSafe);

    console.log("Root Safe Client Address: ", rootSafeClient.account.address);

    // // Create Safe
    // const tx = await rootSafeClient.sendTransaction({
    //     to: RootSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Root Safe: ", tx);

    // // crate providerTosignerEOa
    // const client = createWalletClient({
    //     chain: polygon,
    //     transport: http(RPC_URL!!),
    // });

    // // send transaction
    // const txHashEOA = await client.sendTransaction({
    //     account: signer,
    //     to: RootSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Root Safe: ", txHashEOA);

    const RootSafeProcolKit = await Safe.init({
        provider: RPC_URL!!,
        signer: PRIVATEKEY,
        isL1SafeSingleton: false,
        safeAddress: RootSafe.address,
    });

    const superSafe = await signerToSafeSmartAccount(publicClient(RPC_URL!!), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(313),
    });

    // // Create Safe
    // const tx2 = await rootSafeClient.sendTransaction({
    //     to: superSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Super Safe: ", tx2);

    // // send transaction
    // const txHashEOA2 = await client.sendTransaction({
    //     account: signer,
    //     to: superSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Super Safe: ", txHashEOA2);

    const childSafe = await signerToSafeSmartAccount(publicClient(RPC_URL!!), {
        entryPoint: ENTRYPOINT_ADDRESS_V07,
        signer: signer,
        safeVersion: "1.4.1",
        saltNonce: BigInt(314),
    });

    // // Create Safe
    // const tx3 = await rootSafeClient.sendTransaction({
    //     to: childSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Child Safe: ", tx3);

    // // send transaction
    // const txHashEOA3 = await client.sendTransaction({
    //     account: signer,
    //     to: childSafe.address,
    //     value: parseEther("0.1"),
    // });

    // console.log("Transaction hash Child Safe: ", txHashEOA3);


    console.log(`Root Safe Address: ${RootSafe.address}`);
    console.log(`Second Safe Address: ${superSafe.address}`);
    console.log(`Third Safe Address: ${childSafe.address}`);

    // Enable Palmera Module and Guard in Root Safe, superSafe and childSafe
    // await activateModuleAndGuard(RootSafe, PALMERA_MODULE, PALMERA_GUARD);
    // await snooze(5000);
    // await activateModuleAndGuard(superSafe, PALMERA_MODULE, PALMERA_GUARD);
    // await snooze(5000);
    // await activateModuleAndGuard(childSafe, PALMERA_MODULE, PALMERA_GUARD);

    // Register organization
    await registerOrg(RootSafe, "MyOrg4");
    await snooze(5000);
    // Add Safes to the organization Under Root Safe id: 1
    await createAddSafe(superSafe, 1, "Level 1 Safe v4");
    await snooze(5000);
    // Add Safes to the organization Under SuperSafe Safe id: 2
    await createAddSafe(childSafe, 2, "Level 2 Safe v4");
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
