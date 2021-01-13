const { expect } = require("chai");
const { ethers } = require("hardhat");


// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Listing flow",  function() {

    let arbitrator;
    let market;

    let owner;
    let seller;
    let buyer;

    let cardInfo_hash;
    let metaevidence;

    beforeEach(async function() {

        // Deploying the arbitrator contract.
        const ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();

        // Deploying the market contract && getting signers.
        const MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitrator.address);

        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";
    });

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