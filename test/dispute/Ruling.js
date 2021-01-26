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
    });

    describe("Arbitrator emits ruling", function() {

        it("Should emit the ERC 792 Ruling event", async function() {

            const ruling = 1; // Buyer wins

            let rulingEvent = new Promise((resolve, reject) => {

                market.on("Ruling", (_arbitrator, _disputeID, _ruling, event) => {
                    event.removeListener();

                    expect(_arbitrator).to.equal(arbitrator.address);
                    expect(_disputeID).to.equal(disputeID);
                    expect(_ruling).to.equal(ruling);

                    resolve();
                })

                setTimeout(() => {
                    reject(new Error("Ruling even timeout"));
                }, 30000)
            })
            await arbitrator.connect(owner).rule(disputeID, ruling);
            await rulingEvent;
        })

        it("Should reimburse the winner of the arbitration", async function() {
            const buyerBelanceBefore = await buyer.getBalance()

            const ruling = 1; // Buyer wins
            await arbitrator.connect(owner).rule(disputeID, ruling);
            arbitration = await market.disputeID_to_arbitration(disputeID);
            
            await market.connect(owner).executeRuling(transactionID, disputeID, transactionObj)
            const buyerBalanceAfter = await buyer.getBalance();

            expect(buyerBalanceAfter - buyerBelanceBefore).to.gte(2);
        })
    })
})