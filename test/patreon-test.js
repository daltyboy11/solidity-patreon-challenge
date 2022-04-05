const { expect } = require("chai");
const { ethers } = require("hardhat");
const { 
    time,   // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");
const PatreonJson = require("../artifacts/contracts/Patreon.sol/Patreon.json");


/**
 * Tests for the Patreon contract
 */
describe("Patreon", () => {
    let owner;
    let signer1;
    let signer2;
    let signer3;
    let patreonRegistry;
    let patreon;

    beforeEach(async () => {
        [owner, signer1, signer2, signer3] = await ethers.getSigners();

        const patreonRegistryFactory = await ethers.getContractFactory("PatreonRegistry");
        patreonRegistry = await patreonRegistryFactory.deploy();
        await patreonRegistry.deployed();

        /*
        We cannot retrieve the return value of `createPatreon` directly because it's not a view function. For
        non view functions ethers will return a transaction object. We have two options for fetching the return
        value
            1. Call a getter function after transaction confirmation - We use this technique here by calling
               `getPatreonsForOwner(...)`
            2. If the function emits an event we can parse the event from the transaction receipt and extract
               the desired value. More info on this technique found here:
               https://stackoverflow.com/questions/67239017/how-to-get-ethers-js-response-data
        */
        const tx = await patreonRegistry.connect(owner).createPatreon(
            100,
            time.duration.weeks(1).toNumber(),
            "Test Patreon",
        );
        await tx.wait();

        const patreonAddress = (await patreonRegistry.getPatreonsForOwner(owner.address))[0];
        patreon = new ethers.Contract(patreonAddress, PatreonJson.abi, owner);
    });

    describe("depositFunds", () => {
        beforeEach(async () => {
            await patreon.connect(signer1).subscribe({ value: ethers.utils.parseEther("1.0") });
        });

        it("should accept funds from a subscriber", async () => {
            await patreon.connect(signer1).depositFunds({ value: ethers.utils.parseEther("2.0") });
            const subscription = await patreon.getSubscriber(signer1.address);
            expect(subscription.balance).to.equal(ethers.utils.parseEther("3.0").sub(100));
        });

        it("should reject funds from a non-subscriber", async () => {
            await expect(
                patreon.connect(signer2).depositFunds({ value: ethers.utils.parseEther("0.5") })
            ).to.be.revertedWith("Patreon: not subscribed");
        });

        it("should reject funds from the owner", async () => {
            await expect(
                patreon.connect(owner).depositFunds({value: ethers.utils.parseEther("1.0")})
            ).to.be.revertedWith("Patreon: not subscribed");
        });
    });

    describe("withdraw", () => {
        beforeEach(async () => {
            await patreon.connect(signer1).subscribe({ value: ethers.utils.parseEther("1.0") });
            await patreon.connect(signer2).subscribe({ value: ethers.utils.parseEther("5.0") });
        });

        describe("owner withdrawal", () => {
            it("should reject withdrawal when amount > balance", async () => {
                await expect(
                    patreon.connect(owner).withdraw(201)
                ).to.be.revertedWith("Patreon: owner withdrawing too much");
            });

            it("should allow withdrawal when amount <= owner balance", async () => {
                await expect(() => patreon.connect(owner).withdraw(200)).to.changeEtherBalance(owner, 200);
                expect(await patreon.ownerBalance()).to.equal(0);
            });
        });

        describe("subscriber withdrawal", () => {
            it("should reject withdrawal when amount > balance", async () => {
                await expect(
                    patreon.connect(signer1).withdraw(ethers.utils.parseEther("1.1"))
                ).to.be.revertedWith("Patreon: cannot withdraw more than the balance");
            });

            it("should allow withdrawal when amount <= balance", async () => {
                // The amount withdrawan should be sent to the withdrawer address
                await expect(() => patreon.connect(signer1).withdraw(ethers.utils.parseEther("0.4")))
                    .to.changeEtherBalance(signer1, ethers.utils.parseEther("0.4"));
                const subscription = await patreon.getSubscriber(signer1.address);
                // The amount withdrawan should be subtracted from the withdrawer's contract balance
                expect(subscription.balance).to.equal(ethers.utils.parseEther("0.6").sub(100))
            });
        });
    });

    describe("unsubscribe", () => {
        beforeEach(async () => {
            await patreon.connect(signer1).subscribe({ value: ethers.utils.parseEther("0.5") });
        });

        describe("unsubscribe failure", () => {
            it("should revert when called by non-subscriber", async () => {
                await expect(
                    patreon.connect(signer2).unsubscribe()
                ).to.be.revertedWith("Patreon: not subscribed");
            });
        });

        describe("unsubscribe success", () => {
            let tx;
            let block;
            beforeEach(async () => {
                tx = await patreon.connect(signer1).unsubscribe();
                block = await ethers.provider.getBlock(tx.blockNumber);
            });

            it("should decrement the subscriber count", async () => {
                const subscriberCountBefore = await patreon.subscriberCount({ blockTag: tx.blockNumber - 1});
                const subscriberCountAfter = await patreon.subscriberCount();
                expect(subscriberCountAfter).to.equal(subscriberCountBefore - 1);
            });

            it("should emit an Unsubscribed event", async () => {
                await expect(tx).to.emit(patreon, "Unsubscribed").withArgs(
                    signer1.address,
                    ethers.utils.parseEther("0.5").sub(100),
                    block.timestamp,
                );
            });

            it("should update the Subscriber object", async () => {
                const subscriber = await patreon.getSubscriber(signer1.address);
                expect(subscriber.isSubscribed).to.be.false;
                expect(subscriber.balance).to.equal(0);
            });
        });
    });

    describe("subscribe", () => {
        describe("failed subscription", () => {
            it("should revert when owner attempts to subscribe", async () => {
                await expect(
                    patreon.subscribe({ value: ethers.utils.parseEther("1.0") })
                ).to.be.revertedWith("Patreon: owner cannot call this function");
            });
    
            it("should revert when subscribing without minimum fee", async () => {
                await expect(
                    patreon.connect(signer1).subscribe({ value: "1" })
                ).to.be.revertedWith("Patreon: must subscribe with minimum fee");
            });
        });

        describe("successful subscription", () => {
            let tx;
            let block;
            beforeEach(async () => {
                tx = await patreon.connect(signer1).subscribe({value: ethers.utils.parseEther("0.8")});
                block  = await ethers.provider.getBlock(tx.blockNumber);
            });

            it("should transfer fee to the owner", async () => {
                expect(await patreon.ownerBalance()).to.equal("100");
            });

            it("should update the Subscriber object", async () => {
                const subscriber = await patreon.getSubscriber(signer1.address);
                expect(subscriber.isSubscribed).to.be.true;
                expect(subscriber.balance).to.equal(ethers.utils.parseEther("0.8").sub(100));
                expect(subscriber.subscribedAt).to.equal(block.timestamp);
                expect(subscriber.lastChargedAt).to.equal(block.timestamp);
            });

            it("should increment subscriber count", async () => {
                const subscriberCountBefore = await patreon.subscriberCount({
                    blockTag: tx.blockNumber-1
                });
                const subscriberCountAfter = await patreon.subscriberCount();
                expect(subscriberCountAfter).to.equal(subscriberCountBefore + 1);
            });

            it("should emit a Subscribed event", async () => {
                await expect(tx).to.emit(patreon, "Subscribed").withArgs(
                    signer1.address,
                    ethers.utils.parseEther("0.8"),
                    block.timestamp,
                );
            });

            it("should register subscriber in the patreon registry", async () => {
                const patreonsSubscribedTo = await patreonRegistry.getPatreonsForSubscriber(signer1.address);
                expect(patreonsSubscribedTo.length).to.equal(1);
                expect(patreonsSubscribedTo[0]).to.equal(patreon.address);
            });

            it("should not re-register a past subscriber in the Patreon registry", async () => {
                await patreon.connect(signer1).unsubscribe();
                await patreon.connect(signer1).subscribe({ value: ethers.utils.parseEther("1.0") });

                // If we unsubscribe and then resubcsribe we expect the patreonsSubscribedTo list to be UNCHANGED
                const patreonsSubscribedTo = await patreonRegistry.getPatreonsForSubscriber(signer1.address);
                expect(patreonsSubscribedTo.length).to.equal(1);
                expect(patreonsSubscribedTo[0]).to.equal(patreon.address);
            })
        });
    });

    describe("chargeSubscription", () => {
        let signer1SubscribedAt;

        beforeEach(async () => {
            const signer1Tx = await patreon.connect(signer1).subscribe({ value: ethers.utils.parseEther("6") });
            await patreon.connect(signer2).subscribe({ value: ethers.utils.parseEther("13") });

            const signer1Block = await ethers.provider.getBlock(signer1Tx.blockNumber);
            signer1SubscribedAt = signer1Block.timestamp;

            expect(await patreon.ownerBalance()).to.equal(200);
        });

        it("should revert for non-owner", async () => {
            await expect(
                patreon.connect(signer1).chargeSubscription([signer1.address, signer2.address])
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        describe("charge successful", () => {
            it("should cancel when balance < fee", async () => {
                await patreon.connect(signer3).subscribe({ value: 150 });
                const subscriberCountBefore = await patreon.subscriberCount();

                await time.increase(time.duration.weeks(1));
                const tx = await patreon.chargeSubscription([signer3.address]);
                const block = await ethers.provider.getBlock(tx.blockNumber);
                const subscriberCountAfter = await patreon.subscriberCount();
                const subscription = await patreon.getSubscriber(signer3.address);

                expect(await patreon.ownerBalance()).to.equal(350);
                expect(subscriberCountAfter).to.equal(subscriberCountBefore - 1);
                expect(subscription.isSubscribed).to.be.false;
                expect(subscription.balance).to.equal(0);
                expect(subscription.lastChargedAt).to.equal(block.timestamp);

                await expect(tx).to.emit(patreon, "SubscriptionCanceled").withArgs(
                    signer3.address,
                    50,
                    block.timestamp
                );
                await expect(tx).to.emit(patreon, "Charged").withArgs(
                    signer3.address,
                    50,
                    block.timestamp
                );
            });

            it("should renew when balance >= fee", async () => {
                await time.increase(time.duration.weeks(1));
                const tx = await patreon.chargeSubscription([signer1.address]);
                const block = await ethers.provider.getBlock(tx.blockNumber);
    
                // Fee should be added to owner's balance
                expect(await patreon.ownerBalance()).to.equal(300);
    
                const subscription = await patreon.getSubscriber(signer1.address);
                // Fee should be deducted from subscriber's balance
                expect(subscription.balance).to.equal(ethers.utils.parseEther("6").sub(200));
                // lastChargedAt should be updated 
                expect(subscription.lastChargedAt).to.equal(block.timestamp);
    
                // Charged event should be emittted
                await expect(tx).to.emit(patreon, "Charged")
                    .withArgs(
                        signer1.address,
                        ethers.utils.parseEther("6").sub(100),
                        block.timestamp
                    );
            });

            it("should do nothing if block timestamp is before the next charge period", async () => {;
                const tx = await patreon.chargeSubscription([signer1.address]);

                // We expect no state changes
                expect(await patreon.ownerBalance()).to.equal(200);
                const subscription = await patreon.getSubscriber(signer1.address);
                expect(subscription.isSubscribed).to.be.true;
                expect(subscription.balance).to.equal(ethers.utils.parseEther("6").sub(100));
                expect(subscription.lastChargedAt).to.equal(signer1SubscribedAt);
                expect(subscription.subscribedAt).to.equal(signer1SubscribedAt);

                await expect(tx).to.not.emit(patreon, "Charged");
            })
        });
    });
});
