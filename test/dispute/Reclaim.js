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


        // Shared logic by tests - listing the gift card to be bought by the buyer.
        price = ethers.utils.parseEther("1");
        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";

        listEvent = new Promise((resolve, reject) => {

            market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                
                event.removeListener();

                transactionID = _transactionID;
                transactionObj = _transactionObj;

                resolve();
            })

            setTimeout(() => {
                reject(new Error("TransactionStateUpdate event timeout."));
            }, 60000);
        })

        await market.connect(seller).listNewCard(cardInfo_hash, price);
        await listEvent;

        buyEvent = new Promise((resolve, reject) => {

            market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                
                event.removeListener();

                transactionID = _transactionID;
                transactionObj = _transactionObj;

                resolve();
            });

            setTimeout(() => {
                reject(new Error("TransactionStateUpdate timeout"));
            }, 60000);
        })

        await market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price});
        await buyEvent;
    });

    describe("Reclaim dispute by buyer", function() {

        describe("State update events", function() {
            it("Should emit Transaction state update event", async function() {

                await expect(market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.emit(market, "TransactionStateUpdate")
            })
    
            it("Should emit Dispute state update event", async function() {
                await expect(market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.emit(market, "DisputeStateUpdate")
            })
    
            it("Should emit a reminder event that the seller has to pay fees", async function() {
                await expect(market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.emit(market, "HasToPayArbitrationFee")
            })
        });

        describe("State update event content", function() {
            
            it("Should update the Transaction state", async function() {

                let reclaimTransactionEvent = new Promise((resolve, reject) => {

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
        
                        resolve();
                    })
        
                    setTimeout(() => {
                        reject(new Error("reclaimEvent timeout"));
                    }, 20000);
                });

                await market.connect(buyer).reclaimDisputeByBuyer(
                    transactionID, transactionObj, {value: ethers.utils.parseEther("1")}
                );

                await reclaimTransactionEvent;
            });

            it("Should update the dispute state", async function() {

                let reclaimDisputeEvent = new Promise((resolve, reject) => {

                    market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {
                        
                        event.removeListener();

                        expect(_disputeID).to.equal("0");
                        expect(_transactionID).to.equal(transactionID);
                        expect(_arbitration[0]).to.equal(transactionID);
        
                        resolve();
                    })
        
                    setTimeout(() => {
                        reject(new Error("reclaimEvent timeout"));
                    }, 20000);
                });

                await market.connect(buyer).reclaimDisputeByBuyer(
                    transactionID, transactionObj, {value: ethers.utils.parseEther("1")}
                );

                await reclaimDisputeEvent;
            })

            it("Should remind the seller about paying the arbitraiton fee", async function() {

                let reclaimReminderEvent = new Promise((resolve, reject) => {

                    market.on("HasToPayArbitrationFee", (_transactionID, _party, event) => {
                        
                        event.removeListener();

                        expect(_transactionID).to.equal(transactionID);
                        expect(_party).to.equal(2);
        
                        resolve();
                    })
        
                    setTimeout(() => {
                        reject(new Error("reclaimEvent timeout"));
                    }, 20000);
                });

                await market.connect(buyer).reclaimDisputeByBuyer(
                    transactionID, transactionObj, {value: ethers.utils.parseEther("1")}
                );

                await reclaimReminderEvent;
            })
        
        })

        describe("Revert cases", function() {

            it("Should not allow someone other than the buyer to raise reclaim dispute", async function() {
                await expect(market.connect(foreignParty).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.be.revertedWith(market, "Only the buyer of the card can raise a reclaim dispute.")
            })

            it("Should not be able to raise reclaim dispute once reclaim window has ended", async function() {
                this.timeout(80000);

                await new Promise((resolve, reject) => {
                    setTimeout(() => {
                        // Wait for one minute
                        resolve();
                    }, 60000);
                })

                await expect(market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.be.revertedWith(market, "Cannot reclaim price after the reclaim window is closed.")
            })

            it("Should only allow raising a reclaim dispute once", async function() {

                let reclaimTransactionEvent = new Promise((resolve, reject) => {

                    market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                        
                        event.removeListener();
                        transactionObj = _transactionObj;
                        resolve();
                    })
        
                    setTimeout(() => {
                        reject(new Error("reclaimEvent timeout"));
                    }, 20000);
                });

                let reclaimDisputeEvent = new Promise((resolve, reject) => {

                    market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {
                        
                        event.removeListener();
                        arbitration = _arbitration;
                        resolve();
                    })
        
                    setTimeout(() => {
                        reject(new Error("reclaimEvent timeout"));
                    }, 20000);
                });

                await market.connect(buyer).reclaimDisputeByBuyer(
                    transactionID, transactionObj, {value: ethers.utils.parseEther("1")}
                );
                await reclaimTransactionEvent;
                await reclaimDisputeEvent;

                await expect(market.connect(buyer).reclaimDisputeByBuyer(transactionID, transactionObj, {value: ethers.utils.parseEther("1")}))
                    .to.be.revertedWith(market, "Can raise a reclaim dispute pending state.")
            })
        })
    })
        
});