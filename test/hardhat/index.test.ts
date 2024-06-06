/* eslint-disable no-unused-vars */
/* eslint-disable camelcase */
import { ethers, run, network } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import {
    setBalance,
    impersonateAccount,
} from "@nomicfoundation/hardhat-network-helpers";
import dotenv from "dotenv";
import chai from "chai";
import {
    Palmera_Module,
    Palmera_Module__factory,
    Palmera_Roles,
    Palmera_Roles__factory,
    Palmera_Guard,
    Palmera_Guard__factory,
    Constants,
    Constants__factory,
    DataTypes,
    DataTypes__factory,
    Errors,
    Errors__factory,
    Events,
    Events__factory,
    Random,
    Random__factory,
} from "../typechain-types";

dotenv.config();

const { expect } = chai;

// General Vars
let deployer: SignerWithAddress;
let owner1: SignerWithAddress;
let owner2: SignerWithAddress;
let owner3: SignerWithAddress;
let owner4: SignerWithAddress;
let owner5: SignerWithAddress;
let owner6: SignerWithAddress;
let owner7: SignerWithAddress;
let owner8: SignerWithAddress;
let owner9: SignerWithAddress;
let lastOwner: SignerWithAddress;

// Get Constants
const maxDepthTreeLimit = 50;

const snooze = (ms: any) => new Promise((resolve) => setTimeout(resolve, ms));

describe("Basic Deployment of Palmera Environment", function () {
    before(async () => {
        // Get Signers
        [deployer, owner1, owner2, owner3, owner4, owner5, owner6, owner7, owner8, owner9, lastOwner] = await ethers.getSigners();
        // Deploy Constants Library
        const ConstantsFactory = (await ethers.getContractFactory("Constants", deployer)) as Constants__factory;
        const ConstantsLibrary = await ConstantsFactory.deploy();
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        expect(await ConstantsLibrary.getAddress()).to.properAddress;
        console.log(`Constants Library deployed at: ${await ConstantsLibrary.getAddress()}`);
        // Deploy DataTypes Library
        const DataTypesFactory = (await ethers.getContractFactory("DataTypes", deployer)) as DataTypes__factory;
        const DataTypesLibrary = await DataTypesFactory.deploy();
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        expect(await DataTypesLibrary.getAddress()).to.properAddress;
        console.log(`DataTypes Library deployed at: ${await DataTypesLibrary.getAddress()}`);
        // Deploy Errors Library
        const ErrorsFactory = (await ethers.getContractFactory("Errors", deployer)) as Errors__factory;
        const ErrorsLibrary = await ErrorsFactory.deploy();
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        expect(await ErrorsLibrary.getAddress()).to.properAddress;
        console.log(`Errors Library deployed at: ${await ErrorsLibrary.getAddress()}`);
        // Deploy Events Library
        const EventsFactory = (await ethers.getContractFactory("Events", deployer)) as Events__factory;
        const EventsLibrary = await EventsFactory.deploy();
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        expect(await EventsLibrary.getAddress()).to.properAddress;
        console.log(`Events Library deployed at: ${await EventsLibrary.getAddress()}`);
        // Deploy Random Library
        const RandomFactory = (await ethers.getContractFactory("Random", deployer)) as Random__factory;
        const RandomLibrary = await RandomFactory.deploy();
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        expect(await RandomLibrary.getAddress()).to.properAddress;
        console.log(`Random Library deployed at: ${await RandomLibrary.getAddress()}`);
    });

    it("Deploy Palmera Libraries", async () => {
        // Deploy Palmera Libraries
        console.log("Deploying Palmera Libraries...");
    });

});
