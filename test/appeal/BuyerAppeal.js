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
    let disputeID;

    let listEvent;
    let buyEvent

    let appealFees;

    beforeEach(async function() {

        // Deploying the arbitrator contract.
        const ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();

        // Deploying the market contract && getting signers.
        const MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer, foreignParty] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitrator.address);


        // Shared logic by tests - 
        // 1) seller listing the gift card to be bought - 2) buyer buying the card. - 3) buyer raises reclaim dispute
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
            transactionID, transactionObj, arbitration, {value: ethers.utils.parseEther("1")}
        );
        await reclaimTransactionEvent;
        await reclaimDisputeEvent;

        let disputeEvent = new Promise((resolve, reject) => {

            market.on("Dispute", (_arbitrator, _disputeID, _metaEvidenceID, _transactionID, event) => {

                event.removeListener();
                disputeID = _disputeID;
                resolve();
            })

            setTimeout(() => {
                reject(new Error("feeDeposit event timeout"));
            }, 20000);
        })

        let transactionEvent = new Promise((resolve, reject) => {

            market.on("TransactionStateUpdate", (_transactionID, _transactionObj, event) => {
                event.removeListener();
                transactionObj = _transactionObj
                resolve();
            })

            setTimeout(() => {
                reject(new Error("feeDeposit event timeout"));
            }, 20000);
        })

        await market.connect(seller).payArbitrationFeeBySeller(
            transactionID, transactionID, transactionObj, arbitration, {value: ethers.utils.parseEther("1")}
        );
        await transactionEvent;
        await disputeEvent;

        const ruling = 1; // Buyer wins
        await arbitrator.connect(owner).rule(disputeID, ruling);
        await arbitrator.connect(owner).setAppealPeriod();
        appealFees = ethers.utils.parseEther("25");
    });

    describe("Parties pay appeal fee", function() {

        // describe("Seller pays appeal fee", function() {

            // it("Should emit event to notify buyer to pay appeal fee.", async function() {

            //     await expect(market.connect(seller).payAppealFeeBySeller(
            //         transactionID, transactionObj, arbitration, {value: appealFees}
            //     )).to.emit(market, "HasToPayAppealFee");
            // })

            // it("Should emit dispute state update event", async function() {
                
            //     await expect(market.connect(seller).payAppealFeeBySeller(
            //         transactionID, transactionObj, arbitration, {value: appealFees}
            //     )).to.emit(market, "DisputeStateUpdate");
            // })

            // it("Should update dispute state", async function() {

            //     const WaitingBuyer = 2;

            //     let appealEvent = new Promise((resolve, reject) => {

            //         market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {

            //             event.removeListener();

            //             expect(_transactionID).to.equal(transactionID);
            //             expect(_arbitration[1]).to.equal(WaitingBuyer);

            //             resolve();
            //         })

            //         setTimeout(() => {
            //             reject(new Error("appeal event timeout"));
            //         }, 20000);
            //     })

            //     await market.connect(seller).payAppealFeeBySeller(transactionID, transactionObj, arbitration, {value: appealFees});
            //     await appealEvent;
            // })
        // })

        describe("Buyer pays appeal fee", function() {

            it("Should emit dispute state update event", async function() {

                let appealEvent = new Promise((resolve, reject) => {

                    market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {

                        event.removeListener();

                        arbitration = _arbitration;
                        resolve();
                    })

                    setTimeout(() => {
                        reject(new Error("appeal event timeout"));
                    }, 20000);
                })

                await market.connect(seller).payAppealFeeBySeller(transactionID, transactionObj, arbitration, {value: appealFees});
                await appealEvent;

                await expect(market.connect(buyer).payAppealFeeByBuyer(transactionID, transactionObj, arbitration, {value: appealFees}))
                    .to.emit(market, "DisputeStateUpdate");
            })

            it("Should emit transaction state update", async function() {
                let appealEvent = new Promise((resolve, reject) => {

                    market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {

                        event.removeListener();

                        arbitration = _arbitration;
                        resolve();
                    })

                    setTimeout(() => {
                        reject(new Error("appeal event timeout"));
                    }, 20000);
                })

                await market.connect(seller).payAppealFeeBySeller(transactionID, transactionObj, arbitration, {value: appealFees});
                await appealEvent;

                await expect(market.connect(buyer).payAppealFeeByBuyer(transactionID, transactionObj, arbitration, {value: appealFees}))
                    .to.emit(market, "TransactionStateUpdate");
            })

            it("Should emit Appeal event", async function() {
                let appealEvent = new Promise((resolve, reject) => {

                    market.on("DisputeStateUpdate", (_disputeID, _transactionID, _arbitration, event) => {

                        event.removeListener();

                        arbitration = _arbitration;
                        resolve();
                    })

                    setTimeout(() => {
                        reject(new Error("appeal event timeout"));
                    }, 20000);
                })

                await market.connect(seller).payAppealFeeBySeller(transactionID, transactionObj, arbitration, {value: appealFees});
                await appealEvent;

                await expect(market.connect(buyer).payAppealFeeByBuyer(transactionID, transactionObj, arbitration, {value: appealFees}))
                    .to.emit(market, "Appeal");
            })
        })
    })


})