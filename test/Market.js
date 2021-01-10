const { expect } = require("chai");
const { ethers } = require("hardhat");


// Yet to write tests.

describe("Market contract",  function() {

    let ArbitratorFactory;
    let arbitrator;
    let arbitratorAddress;

    let MarketFactory;
    let market;

    let owner;
    let seller;
    let buyer;

    beforeEach(async function() {

        ArbitratorFactory = await ethers.getContractFactory("SimpleCentralizedArbitrator");
        arbitrator = await ArbitratorFactory.deploy();
        arbitratorAddress = arbitrator.address;

        MarketFactory = await ethers.getContractFactory("Market");
        [owner, seller, buyer] = await ethers.getSigners();

        market = await MarketFactory.deploy(arbitratorAddress);
    });

    describe("Deployment", function() {

        it("Should set the right owner", async function () {
            expect(await market.owner()).to.equal(owner.address);
        });
    })
})