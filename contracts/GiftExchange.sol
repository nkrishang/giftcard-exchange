/**
 * @authors: [@nkirshang]

 * ERC 792 implementation of a gift card exchange. ( ERC 792: https://github.com/ethereum/EIPs/issues/792 )
 * For the idea, see: https://whimsical.com/crypto-gift-card-exchange-VQTH2F7wE8HMvw3DzcSgRi
 * Neither the code, nor the concept is production ready.

 * SPDX-License-Identifier: MIT
**/

// Make imports from the kleros SDK
import "./IArbitrable.sol";
import "./IArbitrator.sol";
import "./IEvidence.sol";

pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

contract GiftExchange is IArbitrable, IEvidence {

    //====== Contract state variables. ======

    address owner; // temp variable for testing. Replace with a Gnosis multisig later.
    IArbitrator public arbitrator; // Initialize arbitrator in the constructor. Make immutable on deployment(?)

    uint arbitrationFeeDepositPeriod = 1 days; // test value should be set much lower e.g. 2 minutes.
    uint reclaimPeriod = 6 hours; // test value should be set much lower e.g. 2 minutes.
    uint numOfRulingOptions = 2;



    //===== Data structures for the contract. =====

    enum Party {None, Buyer ,Seller}
    enum TransactionStatus {Pending, Reclaimed, Disputed, Appealed, Resolved}
    enum DisputeStatus {None, WaitingSeller, WaitingReceiver, Resolved}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}
    

    struct Card {
        bytes32 cardID;
        uint price;
        uint created_at;
        bool forSale;

        address payable seller;
        address payable buyer;

        string cardInfo_URI;
    }

    struct TransactionDispute {
        
        bytes32 cardID;
        DisputeStatus status;

        bool buyerPaidFee;
        bool sellerPaidFee;

        uint arbitrationFee;

        uint createdAt;
    }

    struct Transaction {
        TransactionStatus status;
        
        uint init;
        uint disputeID;

        uint locked_price_amount;
    }

    // Events for state updates, along with the relevant, new state value. 
    event NewListing(bytes32 cardID, Card card);
    event NewTransaction(bytes32 cardID, Transaction transaction);
    event TransactionResolved (address indexed seller, address indexed buyer, bytes32 cardID);

    // Events that signal one or the other party to take an action / notify about a deadline, etc.
    event HasToPayArbitrationFee(bytes32 cardID, Party party);

    mapping(bytes32 => Card) public cards;
    mapping(uint => Transaction) public transactions;
    mapping(bytes32 => uint) public cardID_to_txID;

    mapping(address => bytes32[]) public sellerListings;
    mapping(bytes32 => bool) public validIDs;

    mapping(uint => bytes32) public disputes;
    mapping(bytes32 => TransactionDispute) public disputeReceipts;
    mapping(uint => RulingOptions) public dispute_ruling;

    bytes32[] id_store;
    bytes32[] tx_hashes;

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

    modifier OnlyValidTransaction(bytes32 _cardID) {

        require(validIDs[_cardID], "The card ID is invalid i.e. does not exist on the contract database.");

        _;
    }

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
            cardID: newID,
            price: _price,
            created_at: block.timestamp,
            forSale: true,
            seller: msg.sender,
            buyer: address(0x0),
            cardInfo_URI: _cardInfo
        });
        cards[newID] = newCard;

        emit NewListing(newID, newCard);
    }

    /**
     * @dev Let's a user buy i.e. engage in the sale of a gift card.
    
     * @param _cardID The unique ID of the gift card being purchased.
    **/

    function buyCard(bytes32 _cardID, string calldata _metaevidence) external payable OnlyValidTransaction(_cardID) {

        require(cards[_cardID].forSale, "The sellser has listed the gift card as not for sale, and so, cannot be purchased.");
        require(msg.value == cards[_cardID].price, "Must send exactly the gift card price.");

        cards[_cardID].forSale = false;
        cards[_cardID].buyer = msg.sender;

        Transaction memory newTransaction = Transaction({
            status: TransactionStatus.Pending,

            init: block.timestamp,
            disputeID: 0,

            locked_price_amount: msg.value
        });

        tx_hashes.push(hashTransactionState(newTransaction));
        uint transactionID = tx_hashes.length;

        cardID_to_txID[_cardID] = transactionID;
        transactions[transactionID] = newTransaction;

        emit NewTransaction(_cardID, newTransaction);
        emit MetaEvidence(transactionID, _metaevidence);
    }

    /**
     * @dev Let's the seller withdraw the price amount (if the relevant conditions are met).
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function withdrawPrice(bytes32 _cardID) external OnlyValidTransaction(_cardID) {

        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        // Write a succint filter statement later.
        require(msg.sender == cards[_cardID].seller, "Only the seller can withdraw the price of the card.");
        require(block.timestamp - transaction.init > reclaimPeriod, "Cannot withdraw price while reclaim period is not over.");
        require(transaction.status == TransactionStatus.Pending, "Can only withdraw price if the transaction is in the pending state.");

        transaction.status = TransactionStatus.Resolved;
        msg.sender.transfer(transaction.locked_price_amount);
        transaction.locked_price_amount = 0;

        emit TransactionResolved(msg.sender, cards[_cardID].buyer, _cardID);
    }

    /**
     * @dev Let's the buyer reclaim the price amount (if in the reclaim window) by depositing arbitration fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/
    function reclaimPrice(bytes32 _cardID) external payable OnlyValidTransaction(_cardID) { 

        require(msg.sender == cards[_cardID].buyer, "Only the buyer of the card can reclaim the price paid.");
        require(block.timestamp - transactions[cardID_to_txID[_cardID]].init < reclaimPeriod, "Cannot reclaim price after the reclaim window is closed.");
        require(transactions[cardID_to_txID[_cardID]].status == TransactionStatus.Pending, "Can reclaim price only in pending state.");

        uint arbitrationCost = arbitrator.arbitrationCost(""); // What is passed in for extraData?
        require(msg.value == arbitrationCost, "Must deposit the right arbitration fee to reclaim paid price.");

        transactions[cardID_to_txID[_cardID]].status = TransactionStatus.Reclaimed;

        TransactionDispute memory transactionDispute = TransactionDispute({
            cardID: _cardID,
            status: DisputeStatus.WaitingSeller,

            buyerPaidFee: true,
            sellerPaidFee: false,
            arbitrationFee: msg.value,

            createdAt: block.timestamp
        });

        disputeReceipts[_cardID] = transactionDispute;

        emit HasToPayArbitrationFee(_cardID, Party.Seller);
    }

    

    // Seller engage with dispute fn.

    function SellerPayArbitrationFee(bytes32 _cardID) public payable {

        Card storage card = cards[_cardID];
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(msg.value >= arbitrationCost, "Must send at least arbitration cost to create dispute.");
        require(
            transaction.status == TransactionStatus.Pending, 
            "The transaction cannot be disputed once already disputed; it can only be appealed."
        );

        if(transaction.status == TransactionStatus.Disputed) {
            disputeReceipts[_cardID].arbitrationFee += msg.value;
            disputeReceipts[_cardID].sellerPaidFee = true;

            require(disputeReceipts[_cardID].buyerPaidFee, "This should be impossible."); // testing purposes

            raiseDispute(_cardID, arbitrationCost);

        } else {
            
            transaction.status = TransactionStatus.Disputed;
            TransactionDispute memory transactionDispute = TransactionDispute({
                cardID: _cardID,
                status: DisputeStatus.WaitingSeller,

                buyerPaidFee: false,
                sellerPaidFee: true,
                arbitrationFee: msg.value,

                createdAt: block.timestamp
            });

            disputeReceipts[_cardID] = transactionDispute;

            emit HasToPayArbitrationFee(_cardID, Party.Buyer);
        }
    }


    function BuyerPayArbitrationFee(bytes32 _cardID) public payable {

        Card storage card = cards[_cardID];
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(msg.value >= arbitrationCost, "Must send at least arbitration cost to create dispute.");
        require(
            transaction.status == TransactionStatus.Pending, 
            "The transaction cannot be disputed once already disputed; it can only be appealed."
        );

        if(transaction.status == TransactionStatus.Disputed) {
            disputeReceipts[_cardID].arbitrationFee += msg.value;
            disputeReceipts[_cardID].sellerPaidFee = true;

            require(disputeReceipts[_cardID].buyerPaidFee, "This should be impossible."); // testing purposes

            raiseDispute(_cardID, arbitrationCost);

        } else {
            
            transaction.status = TransactionStatus.Disputed;
            TransactionDispute memory transactionDispute = TransactionDispute({
                cardID: _cardID,
                status: DisputeStatus.WaitingSeller,

                buyerPaidFee: true,
                sellerPaidFee: false,
                arbitrationFee: msg.value,

                createdAt: block.timestamp
            });

            disputeReceipts[_cardID] = transactionDispute;

            emit HasToPayArbitrationFee(_cardID, Party.Seller);
        }
    }

    

    // raiseDispute internal function

    function raiseDispute(bytes32 _cardID, uint _arbitrationCost) internal {

        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        transaction.status = TransactionStatus.Disputed;
        transaction.disputeID = arbitrator.createDispute{value: _arbitrationCost}(numOfRulingOptions, "");

        disputes[transaction.disputeID] = _cardID;
    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller appeal a ruling by depositing appeal fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function appealTransaction(bytes32 _cardID) external payable {
        // appeal period start / end checked by calling the arbitrator
    }

    // Implementation of the rule() function from IArbitrable.
    // Ruling event is directly inherited from IArbitrable.
    function rule(uint256 _disputeID, uint256 _ruling) external override {

        require(msg.sender == address(arbitrator), "Only the arbitrator can give a ruling.");
        emit Ruling(arbitrator, _disputeID, _ruling);

        bytes32 id = disputes[_disputeID];

        if(_ruling == uint(RulingOptions.BuyerWins)) {
            // add security checks (re-entrancy checks)

            //
        }

        if(_ruling == uint(RulingOptions.SellerWins)) {
            // add security checks (re-entrancy checks)

            //
        }

        if(_ruling == uint(RulingOptions.RefusedToArbitrate)) {
            //think about this. 
        }
    }

    function submiteEvidence(bytes32 _cardID, string calldata _evidence) public OnlyValidTransaction(_cardID) {

        Transaction memory transaction = transactions[cardID_to_txID[_cardID]];
        Card memory card = cards[_cardID];

        require(
            msg.sender == card.seller || msg.sender == card.buyer,
            "The caller must be the seller or the buyer."
        );
        require(
            transaction.status == TransactionStatus.Disputed || transaction.status == TransactionStatus.Appealed,
            "Must not send evidence if the dispute is resolved."
        );

        emit Evidence(arbitrator, cardID_to_txID[_cardID], msg.sender, _evidence);
    }

    function hashTransactionState(Transaction memory transaction) public pure returns (bytes32) {
        
        return keccak256(
            abi.encodePacked(
                transaction.status,
                transaction.init,
                transaction.disputeID,
                transaction.locked_price_amount
            )
        );
    }
}

