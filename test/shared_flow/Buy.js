const { expect } = require("chai");
const { ethers } = require("hardhat");


// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Buying flow",  function() {

    let arbitrator;
    let market;

    let owner;
    let seller;
    let buyer;

    let price;
    let cardInfo_hash;
    let metaevidence;

    let transactionID;
    let transactionObj;
    let listEvent;

    beforeEach(async function() {

        // Deploying the arbitrator contract.
        const ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();

        // Deploying the market contract && getting signers.
        const MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitrator.address);


        // Shared logic by tests - listing the gift card to be bought by the buyer.
        price = ethers.utils.parseEther("1");
        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";

        listEvent = new Promise((resolve, reject) => {

            market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                
                event.removeListener();

                transactionID = _transactionID;
                transactionObj = _transactionObj;

                resolve();
            })

            setTimeout(() => {
                reject(new Error("TransactionCreated event timeout."));
            }, 60000);
        })

        await market.connect(seller).listNewCard(cardInfo_hash, price);
        await listEvent;
    });

    describe("Buying a card", function() {


        it("Should emit Transaction state update event when seller buys a card", async function() {

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})).to.emit(market, "TransactionStateUpdate");
        })

        it("Should emit MetaEvidence event when seller buys a card", async function() {

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})).to.emit(market, "MetaEvidence");
        })
        
        it("Should emit a Transaction event with the updated transaction state", async function() {

            let buyEvent = new Promise((resolve, reject) => {

                market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                    
                    event.removeListener();

                    let structEqual = true;

                    if(_transactionObj.length != transactionObj.length) {
                        structEqual = false;
                    } else {
                        for(let i = 0; i < _transactionObj.length; i++) {
                            if(transactionObj[i] != _transactionObj[i]) {
                                structEqual = false;
                                break;
                            }
                        };
                    }

                    expect(_transactionID).to.equal(transactionID);
                    expect(structEqual).to.equal(false);

                    expect(_transactionObj[2]).to.equal(seller.address);
                    expect(_transactionObj[3]).to.equal(buyer.address);

                    resolve();
                });

                setTimeout(() => {
                    reject(new Error("TransactionStateUpdate timeout"));
                }, 20000);
            })

            await market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})
            await buyEvent;
        })

        it("Should emit a Metaevidence event with the metaevidence", async function() {

            let metaevidenceEvent = new Promise((resolve, reject) => {

                market.on("MetaEvidence", (_transactionID, _metaevidence, event) => {
                    
                    event.removeListener();

                    expect(_transactionID).to.equal(transactionID);
                    expect(_metaevidence).to.equal(metaevidence);

                    resolve();
                });

                setTimeout(() => {
                    reject(new Error("TransactionStateUpdate timeout"));
                }, 20000);
            })

            await market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})
            await metaevidenceEvent;
        })

        it("Should not let the buyer buy a card for less than the price (revert case)", async function() {

            const buyerLowPrice = ethers.utils.parseEther("0.9");

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: buyerLowPrice}))
                .to.be.revertedWith("Must send exactly the item price.");
        })

    })
})