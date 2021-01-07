/**
 * @authors: [@nkirshang]

 * ERC 792 implementation of a gift card exchange. ( ERC 792: https://github.com/ethereum/EIPs/issues/792 )
 * For the idea, see: https://whimsical.com/crypto-gift-card-exchange-VQTH2F7wE8HMvw3DzcSgRi
 * Neither the code, nor the concept is production ready.

 * SPDX-License-Identifier: MIT
**/

import "./IArbitrable.sol";
import "./IArbitrator.sol";

pragma solidity ^0.7.0;

contract GiftExchange is IArbitrable {

    // Contract state variables.

    address owner; // temp variable for testing. Replace with a Gnosis multisig later.
    IArbitrator public arbitrator; // Initialize arbitrator in the constructor. Make immutable on deployment(?)

    uint arbitrationFeeDepositPeriod = 1 days; // test value should be set much lower e.g. 2 minutes.
    uint reclaimPeriod = 6 hours; // test value should be set much lower e.g. 2 minutes.
    uint numOfRulingOptions = 2;



    // Data structures for the contract.

    enum Status {Uninitialized, Pending, Resolved, Reclaimed, Disputed, Appealed}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}

    event NewListing(address indexed seller, uint price, bytes32 cardID);
    event NewTransaction(address indexed seller, address indexed buyer, bytes32 cardID);
    event TransactionResolved (address indexed seller, address indexed buyer, bytes32 cardID);
    event BuyerReclaim(address indexed seller, address indexed buyer, bytes32 _cardID);

    struct Card {
        bytes32 id;
        uint price;
        uint created_at;
        bool forSale;

        address payable seller;
        address payable buyer;

        string cardInfo_URI;
    }

    struct Transaction {
        Status status;
        
        uint init;
        uint reclaimedAt;
        uint disputedAt;

        uint disputeID;

        uint buyer_arbitration_fee;
        uint seller_arbitration_fee;

        uint locked_price_amount;
    }

    mapping(bytes32 => Card) public cards;
    mapping(bytes32 => Transaction) public transactions;
    mapping(address => bytes32[]) public sellerListings;

    mapping(uint => bytes32) public disputes;
    mapping(bytes32 => RulingOptions) public dispute_ruling;

    bytes32[] id_store;

    constructor(IArbitrator _arbitrator, address _owner) { // Flesh out as and when.
        arbitrator = _arbitrator;
        owner = _owner;
    }

    
    // Setter functions for contract state variables.
 
    function setReclaimationPeriod(uint _newPeriod) external {
        require(msg.sender == owner, "Only the owner of the contract can change reclaim period.");
        reclaimPeriod = _newPeriod;
    }

    function setArbitrationFeeDepositPeriod(uint _newPeriod) external {
        require(msg.sender == owner, "Only the owner of the contract can change arbitration fee deposit period.");
        arbitrationFeeDepositPeriod = _newPeriod;
    }

    function setNumOfRulingOptions(uint _newNumOfOptions) external {
        require(msg.sender == owner, "Only the owner of the contract can change the number of ruling options.");
        numOfRulingOptions = _newNumOfOptions;
    }

    function setCardPrice(bytes32 _cardID, uint _newPrice) external {
        require(msg.sender == cards[_cardID].seller, "Only the owner of a card can set its price.");
        cards[_cardID].price = _newPrice;
    }

    function setSaleSatus(bytes32 _cardID, bool _status) external {
        require(msg.sender == cards[_cardID].seller, "Only the owner of a card can set its price.");
        cards[_cardID].forSale = _status;
    }


    // Contract main functions

    /**
     * @dev Let's a user list a gift card for sale.
     
     * @param _cardInfo The Unique Resource Locator (URI) for gift card information.
     * @param _price The price set by the seller for the gift card.
    **/

    function listNewCard(string calldata _cardInfo, uint _price) external {

        bytes32 newID = keccak256(abi.encode(_cardInfo, block.timestamp)); // VERY IMPORTANT - generates unique ID for a gift card.
        
        id_store.push(newID);
        sellerListings[msg.sender].push(newID);

        Card memory newCard = Card({
            id: newID,
            price: _price,
            created_at: block.timestamp,
            forSale: true,
            seller: msg.sender,
            buyer: address(0x0),
            cardInfo_URI: _cardInfo
        });
        cards[newID] = newCard;

        emit NewListing(msg.sender, _price, newID);
    }

    /**
     * @dev Let's a user buy i.e. engage in the sale of a gift card.
    
     * @param _cardID The unique ID of the gift card being purchased.
    **/

    function buyCard(bytes32 _cardID) external payable {

        uint id_available = 0;
        for(uint i = 0; i < id_store.length; i++) {
            if(_cardID == id_store[i]) id_available++;
        }
        require(id_available == 1, "The id is not available on the contract database.");

        require(cards[_cardID].forSale, "The sellser has listed the gift card as not for sale, and so, cannot be purchased.");
        require(msg.value == cards[_cardID].price, "Must send exactly the gift card price.");

        cards[_cardID].forSale = false;
        cards[_cardID].buyer = msg.sender;

        Transaction memory newTransaction = Transaction({
            status: Status.Uninitialized,
            init: block.timestamp,
            reclaimedAt: 0,
            disputedAt: 0,
            disputeID: 0,
            buyer_arbitration_fee: 0,
            seller_arbitration_fee: 0,
            locked_price_amount: msg.value
        });

        transactions[_cardID] = newTransaction;
        
        emit NewTransaction(cards[_cardID].seller, msg.sender, _cardID);
    }

    /**
     * @dev Let's the seller withdraw the price amount (if the relevant conditions are met).
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function withdrawPrice(bytes32 _cardID) external {

        Transaction storage transaction = transactions[_cardID];

        // Write a succint filter statement later.
        require(msg.sender == cards[_cardID].seller, "Only the seller can withdraw the price of the card.");
        require(block.timestamp - transaction.init > reclaimPeriod, "Cannot withdraw price while reclaim period is not over.");
        require(transaction.status == Status.Pending, "Can only withdraw price if the transaction is in the pending state.");

        transaction.status = Status.Resolved;
        msg.sender.transfer(transaction.locked_price_amount);
        transaction.locked_price_amount = 0;

        emit TransactionResolved(msg.sender, cards[_cardID].buyer, _cardID);
    }

    /**
     * @dev Let's the buyer reclaim the price amount (if in the reclaim window) by depositing arbitration fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/
    function reclaimPrice(bytes32 _cardID) external payable {

        // Write succint filter statement
        require(msg.sender == cards[_cardID].buyer, "Only the buyer of the card can reclaim the price paid.");
        require(block.timestamp - transactions[_cardID].init < reclaimPeriod, "Cannot reclaim price after the reclaim window is closed.");
        // require(transactions[_cardID].status == Status.Pending, "Can reclaim price only in pending state.");

        uint arbitrationCost = arbitrator.arbitrationCost(""); // What is passed in for extraData?
        require(msg.value == arbitrationCost, "Must deposit the right arbitration fee to reclaim paid price.");

        transactions[_cardID].buyer_arbitration_fee = msg.value;
        transactions[_cardID].reclaimedAt = block.timestamp;

        emit BuyerReclaim(cards[_cardID].seller, msg.sender, _cardID);
    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller dispute the transaction by depositing arbitration fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/
    function disputeTransaction(bytes32 _cardID) external payable {

    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller appeal a ruling by depositing appeal fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function appealTransaction(bytes32 _cardID) external payable {

    }

    // Implementation of the rule() function from IArbitrable.
    // Ruling event is directly inherited from IArbitrable.
    function rule(uint256 _disputeID, uint256 _ruling) external override {

        require(msg.sender == address(arbitrator), "Only the arbitrator can give a ruling.");
        emit Ruling(arbitrator, _disputeID, _ruling);

        bytes32 id = disputes[_disputeID];

        if(_ruling == uint(RulingOptions.BuyerWins)) {
            // add security checks (re-entrancy checks)

            uint refundAmount = transactions[id].buyer_arbitration_fee + transactions[id].locked_price_amount;
            address payable buyer = cards[id].buyer;

            buyer.transfer(refundAmount); // check what the right method is + check units.
        }

        if(_ruling == uint(RulingOptions.SellerWins)) {
            // add security checks (re-entrancy checks)

            uint refundAmount = transactions[id].seller_arbitration_fee + transactions[id].locked_price_amount;
            address payable seller = cards[id].seller;

            seller.transfer(refundAmount); // check what the right method is + check units.
        }

        if(_ruling == uint(RulingOptions.RefusedToArbitrate)) {
            //think about this. 
        }
    }
}

