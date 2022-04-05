const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");


/**
 * Tests for the PatreonRegistry contract
 */
describe("PatreonRegistry", () => {
    let signer1;
    let signer2;
    let patreonRegistry;
    let Patreon;

    async function createPatreon(signer, amount, duration, description) {
        const tx = await patreonRegistry.connect(signer).createPatreon(
            amount,
            duration,
            description
        );
        const block = await ethers.provider.getBlock(tx.blockNumber);
        return [tx, block];
    };

    beforeEach(async () => {
        [signer1, signer2] = await ethers.getSigners();
        const PatreonRegistry = await ethers.getContractFactory("PatreonRegistry");
        patreonRegistry = await PatreonRegistry.deploy();
        Patreon = await ethers.getContractFactory("Patreon");
    });
    
    describe("createPatreon", () => {
        it("successfully create Patreon", async () => {
            const [tx, block] = await createPatreon(
                signer1,
                ethers.utils.parseEther("5.0"),
                time.duration.days(3).toNumber(),
                "my 3-day subscription"
            );

            const patreonAddress = (await patreonRegistry.getPatreonsForOwner(signer1.address))[0];

            // The address of the contract should be stored in the Registry mapping
            expect(await patreonRegistry.isPatreonContract(patreonAddress)).to.be.true;

            // Should increment total count
            expect(await patreonRegistry.numPatreons()).to.equal(1);
            const patreons = await patreonRegistry.getPatreonsForOwner(signer1.address);

            // Signer 1 should have 1 patreon now
            expect(patreons.length).to.equal(1);
            const patreon = await Patreon.attach(patreons[0]);

            // Signer 1 should be the owner of the patreon
            expect(await patreon.owner()).to.equal(signer1.address);
            expect(await patreon.subscriptionFee()).to.equal(ethers.utils.parseEther("5.0"));
            expect(await patreon.subscriptionPeriod()).to.equal(time.duration.days(3).toNumber());
            expect(await patreon.description()).to.equal("my 3-day subscription");

            // A CreatePatreon event should be emitted
            await expect(tx).to.emit(patreonRegistry, "CreatePatreon").withArgs(signer1.address, patreon.address, block.timestamp, "my 3-day subscription");
        });
    });

    describe("registerPatreonSubscription", () => {
        it("should revert for non-patreon contract signers", async () => {
            await expect(
                patreonRegistry.connect(signer1).registerPatreonSubscription(signer1.address)
            ).to.be.revertedWith("Only registered Patreon contracts can call this function")
        });
    });

    describe("getPatreonsForSubscriber", () => {
        it("should return the addresses of the patreon contracts to which the subscriber is subscribed to either now or in the past", async() => {
            // Signer 1 creates two patreons
            for (i in [1, 2]) {
                await createPatreon(
                    signer1,
                    ethers.utils.parseEther(i.toString()),
                    time.duration.days(i).toNumber(),
                    `Patreon ${i}`
                );
            }

            // Signer 2 subscribes to both patreons then subsubscribes from the second
            const patreons = await patreonRegistry.getPatreonsForOwner(signer1.address);
            patreons.forEach(async (patreon) => {
                await Patreon
                    .attach(patreon)
                    .connect(signer2)
                    .subscribe({value: ethers.utils.parseEther("5.0")});
            });
            await Patreon.attach(patreons[1]).connect(signer2).unsubscribe();

            const subscribedPatreons = await patreonRegistry.getPatreonsForSubscriber(signer2.address);
            expect(subscribedPatreons).to.deep.equal(patreons);
        });
    });
});
