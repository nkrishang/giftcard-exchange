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
    
    // mapping(GC id => GC object) * 
    // mapping(GC id => Tx object) *
    // mapping(GC id => Ruling status) *

    //uint arbitrationFeeDepositperiod; -- globally available *

    // implement Arbitrable interface *

    // Setters for global variables * 
    // Determine (along the way) what events are to be set.

    // Flow -
    
    // 1. Seller lists item * 
    // 2. Buyer engages in sale of item * 
    // 3a. No dispute case
    //      - Seller can withraw after arbitrationFeeDepositperiod;
    // 3b. Dispute case
    // Case 1
    //      - Buyer triggers dispute
    //      - Seller responds
    // Case 2
    //      - Buyer reclaims funds
    //      - Seller disputes
    // 4. Appeal case

    
    IArbitrator public arbitrator; // Initialize arbitrator in the constructor.

    uint arbitrationFeeDepositPeriod = 1 days; // test value should be set much lower e.g. 2 minutes.
    uint reclaimPeriod = 6 hours; // test value should be set much lower e.g. 2 minutes.
    uint numOfRulingOptions = 2;

    enum Status {Uninitialized, Pending, Resolved, Reclaimed, Disputed, Appealed}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}

    struct Card {
        bytes32 id;
        uint price;
        uint created_at;
        bool forSale;

        address payable owner;
        address payable buyer;

        string cardInfo_URI;
    }

    struct Transaction {
        Status status;
        uint init;
        uint disputeID;

        uint buyer_arbitration_fee;
        uint seller_arbitration_fee;

        uint locked_price_amount;
    }

    mapping(bytes32 => Card) public cards;
    mapping(bytes32 => Transaction) public transactions;

    mapping(uint => bytes32) public disputes;
    mapping(bytes32 => RulingOptions) public dispute_ruling;

    constructor(IArbitrator _arbitrator) { // Flesh out as and when.
        arbitrator = _arbitrator;
    }
 
    function setReclaimationPeriod(uint _newPeriod) external {
        // security check on msg.sender (figure out contract ownership - at least for test, set an owner address)
        reclaimPeriod = _newPeriod;
    }

    function setArbitrationFeeDepositPeriod(uint _newPeriod) external {
        // security check on msg.sender (figure out contract ownership - at least for test, set an owner address)
        arbitrationFeeDepositPeriod = _newPeriod;
    }

    function setNumOfRulingOptions(uint _newNumOfOptions) external {
        // security check on msg.sender (figure out contract ownership - at least for test, set an owner address)
        numOfRulingOptions = _newNumOfOptions;
    }

    /**
     * @dev Let's a user list a gift card for sale.
     
     * @param _cardInfo The Unique Resource Locator (URI) for gift card information.
     * @param _price The price set by the seller for the gift card.
    **/

    function listNewCard(string calldata _cardInfo, uint _price) external {

        // Rough implementation without security checks, and more.
        // Create setter functions (to be called by the owner only) for price and forSale.

        bytes32 newID = keccak256(abi.encode(_cardInfo, block.timestamp)); // VERY IMPORTANT - generates unique ID for a gift card.

        Card memory newCard = Card({
            id: newID,
            price: _price,
            created_at: block.timestamp,
            forSale: true,
            owner: msg.sender,
            buyer: address(0x0),
            cardInfo_URI: _cardInfo
        });

        cards[newID] = newCard;
    }

    /**
     * @dev Let's a user buy i.e. engage in the sale of a gift card.
    
     * @param _cardID The unique ID of the git card being purchased.
    **/

    function buyCard(bytes32 _cardID) external payable {

        // Rough implementation without security checks, and more.

        require(msg.value == cards[_cardID].price, "Must send exactly the gift card price.");

        cards[_cardID].forSale = false;
        cards[_cardID].buyer = msg.sender;

        Transaction memory newTransaction = Transaction({
            status: Status.Uninitialized,
            init: block.timestamp,
            disputeID: 0,
            buyer_arbitration_fee: 0,
            seller_arbitration_fee: 0,
            locked_price_amount: msg.value
        });

        transactions[_cardID] = newTransaction;
        
        // set off transaction event.
    }

    /**
     * @dev Let's the seller withdraw the price amount (if the relevant conditions are met).
    
     * @param _cardID The unique ID of the git card in concern.
    **/

    function withdrawPrice(bytes32 _cardID) external {
        // Make security checks + timestamp checks.
    }

    /**
     * @dev Let's the buyer reclaim the price amount (if in the reclaim window) by depositing arbitration fee.
    
     * @param _cardID The unique ID of the git card in concern.
    **/
    function reclaimPrice(bytes32 _cardID) external payable {
        
    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller dispute the transaction by depositing arbitration fee.
    
     * @param _cardID The unique ID of the git card in concern.
    **/
    function disputeTransaction(bytes32 _cardID) external payable {

    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller appeal a ruling by depositing appeal fee.
    
     * @param _cardID The unique ID of the git card in concern.
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
            address payable seller = cards[id].owner;

            seller.transfer(refundAmount); // check what the right method is + check units.
        }

        if(_ruling == uint(RulingOptions.RefusedToArbitrate)) {
            //think about this. 
        }
    }
}

