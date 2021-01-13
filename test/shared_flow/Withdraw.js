const { expect } = require("chai");
const { ethers } = require("hardhat");


// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Buying flow",  function() {

    let arbitrator;
    let market;

    let owner;
    let seller;
    let buyer;
    let foreignParty;

    let price;
    let cardInfo_hash;
    let metaevidence;

    let transactionID;
    let transactionObj;
    let arbitration;

    let listEvent;
    let buyEvent

    beforeEach(async function() {

        // Deploying the arbitrator contract.
        const ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();

        // Deploying the market contract && getting signers.
        const MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer, foreignParty] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitrator.address);


        // Shared logic by tests - 1) seller listing the gift card to be bought - 2) buyer buying the card.
        price = ethers.utils.parseEther("1");
        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";

        listEvent = new Promise((resolve, reject) => {

            market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                
                event.removeListener();

                arbitration = _arbitration;
                transactionID = _transactionID;
                transactionObj = _transactionObj;

                resolve();
            })

            setTimeout(() => {
                reject(new Error("TransactionCreated event timeout."));
            }, 60000);
        })

        buyEvent = new Promise((resolve, reject) => {

            market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                
                event.removeListener();
                transactionObj = _transactionObj;

                resolve();
            });

            setTimeout(() => {
                reject(new Error("TransactionStateUpdate timeout"));
            }, 60000);
        })

        await market.connect(seller).listNewCard(cardInfo_hash, price);
        await listEvent;

        await market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price});
        await buyEvent;
    });


    describe("Buyer withdrawal of card URI hash", function() {

        it("Should let the buyer get the gift card URI", async function() {

            expect(await market.connect(buyer).getCardInfo(transactionID, transactionObj)).to.equal(cardInfo_hash);
        })

        it("Should not let anyone other than the buyer get the gift card URI", async function() {
            
            await expect(market.connect(foreignParty).getCardInfo(transactionID, transactionObj))
                .to.be.revertedWith("Only the buyer can retrieve item info.");
        })
    });

    describe("Seller withdrawal of price", async function() {
        
        it("Should not let the seller withdraw price before the reclaim period is over", async function() {
            
            await expect(market.connect(seller).withdrawPriceBySeller(transactionID, transactionObj))
                .to.be.revertedWith("Cannot withdraw price while reclaim period is not over.");
        })

        it("Should let the seller withdraw price once the reclaim period is over", async function() {
            
            this.timeout(80000);

            await new Promise((resolve, reject) => {
                setTimeout(() => {
                    // Wait for one minute
                    resolve();
                }, 60000);
            })

            await expect(market.connect(seller).withdrawPriceBySeller(transactionID, transactionObj))
                .to.emit(market, "TransactionResolved");
        })

        it("Should not let the seller withdraw price if the transaction has been disputed", async function() {
            this.timeout(80000);

            // Update transactionObj with Tx event emitted by reclaimDisputeByBuyer.

            let reclaimEvent = new Promise((resolve, reject) => {

                market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                    
                    event.removeListener();
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("reclaimEvent timeout"));
                }, 20000);
            })

            await market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, arbitration, {value: ethers.utils.parseEther("1")});
            await reclaimEvent;

            await new Promise((resolve, reject) => {
                setTimeout(() => {
                    // Wait for one minute
                    resolve();
                }, 60000);
            })

            await expect(market.connect(seller).withdrawPriceBySeller(transactionID, transactionObj))
                .to.be.revertedWith("Can only withdraw price if the transaction is in the pending state.");
        })

        it("Should not let anyone other than the seller withdraw price.", async function() {
            this.timeout(80000);

            await new Promise((resolve, reject) => {
                setTimeout(() => {
                    // Wait for one minute
                    resolve();
                }, 60000);
            })

            await expect(market.connect(foreignParty).withdrawPriceBySeller(transactionID, transactionObj))
                .to.be.revertedWith("Only the seller can call a seller-withdraw function.");
        })
    })

});