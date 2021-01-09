const { expect } = require("chai");
const { ethers } = require("hardhat");

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

    describe("Listing a gift card", function() {

        it("Should update the contract's id store", async function() {

            // Repeat code for tests
            const cardInfo = "dummy information - should be a URI";
            const price = ethers.utils.parseEther("5");
            const cardID = await market.connect(seller).listNewCard(cardInfo, price);

            console.log(cardID);

            const id_store = await market.id_store(0);
            console.log(`id_store: ${id_store}`);

            expect(cardID.hash).to.equal(id_store);
        })

        // it("Should update seller listings", async function() {

        //     // Repeat code for tests
        //     const cardInfo = "dummy information - should be a URI";
        //     const price = ethers.utils.parseEther("5");
        //     const cardID = await market.connect(seller).listNewCard(cardInfo, price);

        //     const sellerListings = await market.sellerListings(seller.address);

        //     expect(sellerListings.length).to.equal(1);
        //     expect(sellerListings[0]).to.equal(cardID);
        // })

        // it("Should add listed card to the card store", async function() {

        //     // Repeat code for tests
        //     const cardInfo = "dummy information - should be a URI";
        //     const price = ethers.utils.parseEther("5");
        //     const cardID = await market.connect(seller).listNewCard(cardInfo, price);

        //     const cardObject = await market.cards(cardID);

        //     expect(cardObject.cardInfo).to.equal(cardInfo);
        // })
    })
})