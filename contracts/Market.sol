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

import "hardhat/console.sol";

contract Market is IArbitrable, IEvidence {

    //====== Contract state variables. ======

    address public owner; // temp variable for testing. Replace with a Gnosis multisig later.
    IArbitrator public arbitrator; // Initialize arbitrator in the constructor. Make immutable on deployment(?)

    uint arbitrationFeeDepositPeriod = 1 days; // test value should be set much lower e.g. 2 minutes.
    uint reclaimPeriod = 6 hours; // test value should be set much lower e.g. 2 minutes.
    uint numOfRulingOptions = 2;



    //===== Data structures for the contract. =====

    enum Party {None, Buyer ,Seller}
    enum TransactionStatus {Pending, Reclaimed, Disputed, Appealed, Resolved}
    // Don't forget to set dispute statuses
    enum DisputeStatus {None, WaitingSeller, WaitingBuyer, InProcess, Resolved}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}
    

    struct Card {
        bytes32 cardID; // redundant? (Think of optimizing storage)
        uint price;
        uint created_at;
        bool forSale;

        address payable seller;
        address payable buyer;

        string cardInfo_URI;
    }

    struct Transaction {
        TransactionStatus status;
        
        uint init;
        uint disputeID;

        uint locked_price_amount;
    }

    struct TransactionDispute {
        
        bytes32 cardID;
        DisputeStatus status;

        uint buyerFee;
        uint sellerFee;

        uint arbitrationFee;

        uint createdAt;
    }

    struct TransactionAppeal {
        uint appealRound;

        uint buyerFee;
        uint sellerFee;
        DisputeStatus status;

        uint appealFee;

        uint createdAt;
        uint deadline;
    }


    // Events for state updates, along with the relevant, new state value. 
    event NewListing(bytes32 cardID, Card card);
    event NewTransaction(bytes32 cardID, Transaction transaction);
    event TransactionResolved (address indexed seller, address indexed buyer, bytes32 cardID);

    // Events that signal one or the other party to take an action / notify about a deadline, etc.
    event HasToPayArbitrationFee(bytes32 cardID, Party party);
    event HasPaidArbitrationFee(bytes32 cardID, Party party);

    event HasToPayAppealFee(bytes32 cardID, Party party);
    event HasPaidAppealFee(bytes32 cardID, Party party);

    mapping(bytes32 => Card) public cards;
    mapping(uint => Transaction) public transactions;
    mapping(bytes32 => uint) public cardID_to_txID;

    mapping(address => bytes32[]) public sellerListings;
    mapping(bytes32 => bool) public validIDs; // ok

    mapping(uint => bytes32) public disputes;
    mapping(bytes32 => TransactionDispute) public disputeReceipts;
    mapping(bytes32 => TransactionAppeal) public appealReceipts; 
    mapping(uint => RulingOptions) public dispute_ruling;

    bytes32[] public id_store;
    bytes32[] tx_hashes;

    constructor(address _arbitrator) { // Flesh out as and when.
        arbitrator = IArbitrator(_arbitrator);
        owner = msg.sender;
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

    // Getters
    // function getArbitrationCost() external view returns (uint) {
    //     return arbitrator.arbitrationCost("");
    // }

    // function getSellerListings(address seller) external view returns(bytes32[] memory) {
    //     return sellerListings[seller];
    // }

    // function getCard(bytes32 _cardID) external view returns(Card memory) {
    //     return cards[_cardID];
    // }


    // Contract main functions

    modifier OnlyValidTransaction(bytes32 _cardID) {

        require(validIDs[_cardID], "The card ID is invalid i.e. does not exist on the contract database.");

        _;
    }

     bytes32 public stateID;

    /**
     * @dev Let's a user list a gift card for sale.
     
     * @param _cardInfo The Unique Resource Locator (URI) for gift card information.
     * @param _price The price set by the seller for the gift card.
    **/

    function listNewCard(string calldata _cardInfo, uint _price) external returns (bytes32) {
        
        // VERY IMPORTANT - generates unique ID for a gift card.
        bytes32 newID = keccak256(abi.encode(_cardInfo, msg.sender, block.timestamp)); 
        
        stateID = newID;

        id_store.push(newID);
        validIDs[newID] = true;
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

        return newID;
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

        TransactionDispute memory transactionDispute = TransactionDispute({
            cardID: _cardID,
            status: DisputeStatus.None,

            buyerFee: 0,
            sellerFee: 0,
            arbitrationFee: 0,

            createdAt: 0
        });

        tx_hashes.push(hashTransactionState(newTransaction));
        uint transactionID = tx_hashes.length;

        cardID_to_txID[_cardID] = transactionID;
        transactions[transactionID] = newTransaction;
        disputeReceipts[_cardID] = transactionDispute;

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

        TransactionDispute storage transactionDispute = disputeReceipts[_cardID];

        transactionDispute.status = DisputeStatus.WaitingSeller;
        transactionDispute.buyerFee = msg.value;
        transactionDispute.arbitrationFee = msg.value;
        transactionDispute.createdAt = block.timestamp;

        emit HasToPayArbitrationFee(_cardID, Party.Seller);
    }

    

    // Seller engage with dispute fn.

    function payArbitrationFeeBySeller(bytes32 _cardID) public payable {

        TransactionDispute storage transactionDispute = disputeReceipts[_cardID];
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - transactionDispute.sellerFee), 
            "Must send at least arbitration cost to create dispute."
        );
        
        transactionDispute.arbitrationFee += msg.value;
        transactionDispute.sellerFee += msg.value;

        if(transactionDispute.buyerFee < arbitrationCost) {
            transactionDispute.status = DisputeStatus.WaitingBuyer;
            emit HasToPayArbitrationFee(_cardID, Party.Buyer);
        } else {
            raiseDispute(_cardID, arbitrationCost, transaction, transactionDispute);
        }
    }


    function payArbitrationFeeByBuyer(bytes32 _cardID) public payable {

        TransactionDispute storage transactionDispute = disputeReceipts[_cardID];
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - transactionDispute.buyerFee), 
            "Must send at least arbitration cost to create dispute."
        );
        
        transactionDispute.arbitrationFee += msg.value;
        transactionDispute.buyerFee += msg.value;

        if(transactionDispute.sellerFee < arbitrationCost) {
            transactionDispute.status = DisputeStatus.WaitingBuyer;
            emit HasToPayArbitrationFee(_cardID, Party.Seller);
        } else {
            raiseDispute(_cardID, arbitrationCost, transaction, transactionDispute);
        }
    }

    

    // raiseDispute internal function

    function raiseDispute(
        bytes32 _cardID,
        uint _arbitrationCost,
        Transaction memory _transaction,
        TransactionDispute memory _transactionDispute
        ) internal {

        _transaction.status = TransactionStatus.Disputed;
        _transaction.disputeID = arbitrator.createDispute{value: _arbitrationCost}(numOfRulingOptions, "");

        _transactionDispute.status = DisputeStatus.InProcess;

        disputes[_transaction.disputeID] = _cardID;

        // Seller | Buyer fee reimbursements.

        if(_transactionDispute.sellerFee > _arbitrationCost) {
            uint extraFee = _transactionDispute.sellerFee - _arbitrationCost;
            _transactionDispute.sellerFee = _arbitrationCost;
            cards[_cardID].seller.transfer(extraFee);
        }

        if(_transactionDispute.buyerFee > _arbitrationCost) {
            uint extraFee = _transactionDispute.buyerFee - _arbitrationCost;
            _transactionDispute.buyerFee = _arbitrationCost;
            cards[_cardID].buyer.transfer(extraFee);
        }
    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller appeal a ruling by depositing appeal fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function payAppealFeeBySeller(bytes32 _cardID) public payable {
        // appeal period start / end checked by calling the arbitrator
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];
        TransactionAppeal storage transactionAppeal = appealReceipts[_cardID];
        require(transaction.status >= TransactionStatus.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(transaction.disputeID, "");
        require(msg.value >= appealCost - transactionAppeal.sellerFee, "Not paying sufficient appeal fee.");

        transactionAppeal.sellerFee += msg.value;
        transactionAppeal.appealFee += msg.value;

        if(transactionAppeal.buyerFee < appealCost) {
            transactionAppeal.status = DisputeStatus.WaitingBuyer;
            emit HasToPayAppealFee(_cardID, Party.Buyer);
        } else {
            transactionAppeal.appealRound++;
         }
    }

    function payAppealFeeByBuyer(bytes32 _cardID) public payable {
        // appeal period start / end checked by calling the arbitrator
        Transaction storage transaction = transactions[cardID_to_txID[_cardID]];
        TransactionAppeal storage transactionAppeal = appealReceipts[_cardID];
        require(transaction.status >= TransactionStatus.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(transaction.disputeID, "");
        require(msg.value >= appealCost - transactionAppeal.buyerFee, "Not paying sufficient appeal fee.");

        transactionAppeal.buyerFee += msg.value;
        transactionAppeal.appealFee += msg.value;

        if(transactionAppeal.sellerFee < appealCost) {
            transactionAppeal.status = DisputeStatus.WaitingSeller;
            emit HasToPayAppealFee(_cardID, Party.Seller);
        } else {
            transactionAppeal.appealRound++;
        }
    }

    function appealTransaction(
        bytes32 _cardID,
        uint _appealCost,
        Transaction memory _transaction,
        TransactionAppeal memory _transactionAppeal
        ) internal {
        
        _transactionAppeal.appealRound++;
        _transaction.status = TransactionStatus.Appealed;
        arbitrator.createDispute{value: _appealCost}(_transaction.disputeID, "");

        _transactionAppeal.status = DisputeStatus.InProcess;

        disputes[_transaction.disputeID] = _cardID;

        // Seller | Buyer fee reimbursements.

        if(_transactionAppeal.sellerFee > _appealCost) {
            uint extraFee = _transactionAppeal.sellerFee - _appealCost;
            _transactionAppeal.sellerFee = _appealCost;
            cards[_cardID].seller.transfer(extraFee);
        }

        if(_transactionAppeal.buyerFee > _appealCost) {
            uint extraFee = _transactionAppeal.buyerFee - _appealCost;
            _transactionAppeal.buyerFee = _appealCost;
            cards[_cardID].buyer.transfer(extraFee);
        }
    }

    // Implementation of the rule() function from IArbitrable.
    // Ruling event is directly inherited from IArbitrable.
    function rule(uint256 _disputeID, uint256 _ruling) external override {

        require(msg.sender == address(arbitrator), "Only the arbitrator can give a ruling.");

        bytes32 cardID = disputes[_disputeID];
        Card memory card = cards[cardID];
        Transaction memory transaction = transactions[cardID_to_txID[cardID]];

        uint refundAmount;

        if(_ruling > uint(RulingOptions.RefusedToArbitrate)) {
            transaction.status = TransactionStatus.Resolved;
            refundAmount += transaction.locked_price_amount;
            transaction.locked_price_amount = 0;
        }

        if(_ruling == uint(RulingOptions.BuyerWins)) {
            
            refundAmount += disputeReceipts[cardID].buyerFee;
            refundAmount += appealReceipts[cardID].buyerFee;
            
            card.buyer.transfer(refundAmount);
        }

        if(_ruling == uint(RulingOptions.SellerWins)) {
            refundAmount += disputeReceipts[cardID].sellerFee;
            refundAmount += appealReceipts[cardID].sellerFee;
            
            card.seller.transfer(refundAmount);
        }

        if(_ruling == uint(RulingOptions.RefusedToArbitrate)) {
            refundAmount += disputeReceipts[cardID].arbitrationFee;
            refundAmount += appealReceipts[cardID].appealFee;

            card.seller.transfer(refundAmount / 2);
            card.buyer.transfer(refundAmount / 2);
        }

        emit Ruling(arbitrator, _disputeID, _ruling);
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

