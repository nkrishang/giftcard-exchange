const { expect } = require("chai");
const { ethers } = require("hardhat");


// The tests in "Listing a gift card" are an example of how to test events with ethers js.
// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Listing flow",  function() {

    let ArbitratorFactory;
    let arbitrator;
    let arbitratorAddress;

    let MarketFactory;
    let market;

    let owner;
    let seller;
    let buyer;

    let cardInfo_hash;
    let metaevidence;

    beforeEach(async function() {

        ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();
        arbitratorAddress = arbitrator.address;

        MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitratorAddress);

        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";
    });

    describe("Deployment", function() {

        it("Should set the right owner", async function () {
            expect(await market.owner()).to.equal(owner.address);
        });

        it("Should set SimpleCentralizedArbitrator as the arbitrator", async function () {
            expect(await market.arbitrator()).to.equal(arbitratorAddress);
        })
    })

    describe("Listing a giftcard", function() {

        it("Should emit a Transaction event when a giftcard is listed", async function() {
            let price = ethers.utils.parseEther("1");
            await expect(market.listNewCard(cardInfo_hash, price)).to.emit(market, "TransactionCreated");
        })

        it("Should emit a Transaction event with the updated transaction state", async function() {
        
            let price = ethers.utils.parseEther("1");

            let transactionPromise = new Promise((resolve, reject) => {
                market.on("TransactionCreated", (_transactionID, _transaction, _arbitration, event) => {
                    
                    event.removeListener();

                    // Check if the event parameters are retrieved correctly.

                    expect(_transactionID.toString()).to.equal(numOfTransactions.toString());
                    expect(_arbitration[0].toString()).to.equal(numOfTransactions.toString());

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("timeout while waiting for event."));
                }, 30000);
            })

            await market.listNewCard(cardInfo_hash, price);
            const numOfTransactions = await market.getNumOfTransactions();

            await transactionPromise;
        })

    })
})