const { expect } = require("chai");
const { ethers } = require("hardhat");


// The tests in "Listing a gift card" are an example of how to test events with ethers js.
// For more on how to test events with ethers, see - https://github.com/ethers-io/ethers.js/issues/283

describe("Market contract - Deployment",  function() {

    let arbitrator;

    let MarketFactory;
    let market;

    let owner;
    let seller;
    let buyer;

    let cardInfo_hash;
    let metaevidence;

    beforeEach(async function() {

        const ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();

        MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitrator.address);

        cardInfo_hash = ethers.utils.keccak256(ethers.utils.formatBytes32String("giftcard information"));
        metaevidence = "ERC 1497 compliant metavidence";
    });

    describe("Deployment in Market file", function() {

        it("Should set the right owner", async function () {
            expect(await market.owner()).to.equal(owner.address);
        });

        it("Should set SimpleCentralizedArbitrator as the arbitrator", async function () {
            expect(await market.arbitrator()).to.equal(arbitrator.address);
        })
    });

    // describe("Dispute Cases", function() {

    //     describe("No dispute", function() {

    //     });
    
    //     describe("Dispute won by seller but no appeal", function() {
    
    //     });
    
    //     describe("Dispute won by buyer but no appeal", function() {
    
    //     });
    
    //     describe("Dispute and appeal won by seller", function() {
    
    //     })
    
    //     describe("Dispute and appeal won by buyer", function() {
    
    //     })
    
    //     describe("Arbitrator refuses to arbitrate", function() {
    
    //     });
    // })
})