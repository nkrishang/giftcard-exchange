const { expect } = require("chai");
const { ethers } = require("hardhat");


// The tests in "Listing a gift card" are an example of how to test events with ethers js.
// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Buying flow",  function() {

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

    describe("Buying a card", function() {


        it("Should emit Transaction state update event when seller buys a card", async function() {

            // List card first ---> Get transaction ID and Transaction struct object.
            let price = ethers.utils.parseEther("1");

            let transactionID;
            let transactionObj; // init as an array. If that doesn't work, init as an object

            let listEvent = new Promise((resolve, reject) => {

                market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {

                    event.removeListener();

                    transactionID = _transactionID;
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("TransactionCreated event timeout."));
                }, 20000);
            })

            await market.connect(seller).listNewCard(cardInfo_hash, price);
            await listEvent;

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})).to.emit(market, "TransactionStateUpdate");
        })

        it("Should emit MetaEvidence event when seller buys a card", async function() {
            // List card first ---> Get transaction ID and Transaction struct object.
            let price = ethers.utils.parseEther("1");

            let transactionID;
            let transactionObj; // init as an array. If that doesn't work, init as an object

            let listEvent = new Promise((resolve, reject) => {

                market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                    
                    event.removeListener();

                    transactionID = _transactionID;
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("TransactionCreated event timeout."));
                }, 20000);
            })

            await market.connect(seller).listNewCard(cardInfo_hash, price);
            await listEvent;

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: price})).to.emit(market, "MetaEvidence");
        })
        
        it("Should emit a Transaction event with the updated transaction state", async function() {
            // List card first ---> Get transaction ID and Transaction struct object.
            let price = ethers.utils.parseEther("1");

            let transactionID;
            let transactionObj; // init as an array. If that doesn't work, init as an object

            let listEvent = new Promise((resolve, reject) => {

                market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                    
                    event.removeListener();

                    transactionID = _transactionID;
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("TransactionCreated event timeout."));
                }, 20000);
            })

            await market.connect(seller).listNewCard(cardInfo_hash, price);
            await listEvent;

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
            // List card first ---> Get transaction ID and Transaction struct object.
            let price = ethers.utils.parseEther("1");

            let transactionID;
            let transactionObj; // init as an array. If that doesn't work, init as an object

            let listEvent = new Promise((resolve, reject) => {

                market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                    
                    event.removeListener();

                    transactionID = _transactionID;
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("TransactionCreated event timeout."));
                }, 20000);
            })

            await market.connect(seller).listNewCard(cardInfo_hash, price);
            await listEvent;

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
            // List card first ---> Get transaction ID and Transaction struct object.
            const price = ethers.utils.parseEther("1");

            let transactionID;
            let transactionObj; // init as an array. If that doesn't work, init as an object

            let listEvent = new Promise((resolve, reject) => {

                market.on("TransactionCreated", (_transactionID, _transactionObj, _arbitration, event) => {
                    
                    event.removeListener();

                    transactionID = _transactionID;
                    transactionObj = _transactionObj;

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("TransactionCreated event timeout."));
                }, 20000);
            })

            await market.connect(seller).listNewCard(cardInfo_hash, price);
            await listEvent;

            const buyerLowPrice = ethers.utils.parseEther("0.9");

            await expect(market.connect(buyer).buyCard(transactionID, transactionObj, metaevidence, {value: buyerLowPrice}))
                .to.be.revertedWith("Must send exactly the item price.");
        })

    })
})