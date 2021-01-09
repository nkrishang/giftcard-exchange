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
    enum Status {None, Pending, Reclaimed, Disputed, Appealed, Resolved}
    enum DisputeStatus {None, WaitingSeller, WaitingBuyer, InProcess, Resolved}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}
    

    struct Transaction {
        uint price;
        bool forSale;

        address payable seller;
        address payable buyer;
        string cardInfo_URI;

        Status status;
        uint init;
        uint locked_price_amount;

        uint disputeID;
    }

    struct Arbitration {
        
        uint transactionID;
        DisputeStatus status;

        uint buyerArbitrationFee;
        uint sellerArbitrationFee;
        uint arbitrationFee;

        uint appealRound;

        uint buyerAppealFee;
        uint sellerAppealFee;
        uint appealFee;
        
    }

    bytes32[] tx_hashes;

    mapping(uint => bytes32) public ID_to_hash; // Necessary?
    mapping(bytes32 => bool) public validTx; // Necessary?

    mapping(uint => uint) public disputes;
    mapping(uint => Arbitration) public arbitrations;

    // Transaction level events 
    event TransactionCreated(uint indexed transactionID, Transaction transaction);
    event TransactionStateUpdate(uint indexed transactionID, Transaction transaction);
    event TransactionResolved(uint indexed transactionID, Transaction transaction);

    // Fee Payment reminders
    event HasToPayArbitrationFee(uint indexed transactionID, Party party);
    event HasPaidArbitrationFee(uint indexed transactionID, Party party);

    event HasToPayAppealFee(uint indexed transactionID, Party party);
    event HasPaidAppealFee(uint indexed transactionID, Party party);

    // Dispute event from IERC 1497

    

    constructor(address _arbitrator) { // Flesh out as and when.
        arbitrator = IArbitrator(_arbitrator);
        owner = msg.sender;
    }


    // Contract main functions

    modifier OnlyValidTransaction(uint _transactionID) {

        require(validTx[ID_to_hash[_transactionID]], "The card ID is invalid i.e. does not exist on the contract database.");

        _;
    }

    /**
     * @dev Let's a user list a gift card for sale.
     
     * @param _cardInfo The Unique Resource Locator (URI) for gift card information.
     * @param _price The price set by the seller for the gift card.
    **/

    function listNewCard(string calldata _cardInfo, uint _price) external returns (uint transactionID) {

        Transaction memory transaction = Transaction({
            price: _price,
            forSale: true,

            seller: msg.sender,
            buyer: address(0x0),
            cardInfo_URI: _cardInfo,

            status: Status.None,

            init: 0,
            locked_price_amount: 0,

            disputeID: 0 
        });

        bytes32 tx_hash = hashTransactionState(newTransaction);
        tx_hashes.push(tx_hash);
        
        transactionID = tx_hashes.length;

        ID_to_hash[transactionID] = tx_hash;
        validTx[transactionID] = true;

        emit TransactionCreated(transactionID, transaction);
    }


    /**
     * @dev Let's a user buy i.e. engage in the sale of a gift card.
    
     * @param _cardID The unique ID of the gift card being purchased.
    **/

    function buyCard(
        uint _transactionID,
        Transaction memory _transaction,
        string calldata _metaevidence
    ) external payable OnlyValidTransaction(_transactionID) {

        require(_transaction.status == Status.None, "Can't purchase an item already engaged in sale.");
        require(_transaction.forSale, "Cannot purchase item not for sale.");
        require(msg.value == _transaction.price, "Must send exactly the item price.");

        validTx[hashTransactionState(_transaction)] = false;

        _transaction.status = Status.Pending;
        _transaction.forSale = false;
        _transaction.buyer = msg.sender;
        _transaction.init = block.timestamp;

        updateTxHash(_transactionID, _transaction);

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit MetaEvidence(_transactionID, _metaevidence);
    }

    /**
     * @dev Let's the seller withdraw the price amount (if the relevant conditions are met).
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function withdrawPriceBySeller(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID) {

        // Write a succint filter statement later.
        require(msg.sender == _transaction.seller, "Only the seller can withdraw the price of the card.");
        require(block.timestamp - _transaction.init > reclaimPeriod, "Cannot withdraw price while reclaim period is not over.");
        require(transaction.status == Status.Pending, "Can only withdraw price if the transaction is in the pending state.");

        validTx[hashTransactionState(_transaction)] = false;

        _transaction.status = TransactionStatus.Resolved;
        
        uint amount = _transaction.locked_price_amount;
        transaction.locked_price_amount = 0;

        msg.sender.transfer(amount);

        updateTxHash(_transactionID, _transaction);
        emit TransactionResolved(_transactionID, _transaction);
    }

    /**
     * @dev Let's the buyer reclaim the price amount (if in the reclaim window) by depositing arbitration fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/
    function reclaimPriceByBuyer(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID) {

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

    // Utility functionss

    function hashTransactionState(Transaction memory transaction) public pure returns (bytes32) {
        
        // Hash the whole transaction

        return keccak256(
            abi.encodePacked(
                transaction.price,
                transaction.forSale,

                transaction.seller,
                transaction.buyer,
                transaction.cardInfo_URI,

                transaction.status,
                transaction.init,
                transaction.locked_price_amount,

                transaction.disputeID
            )
        );
    }

    function updateTxHash(uint _transactionID, Transaction memory _transaction) internal {
        
        bytes32 new_tx_hash = hashTransactionState(_transaction);

        validTx[new_tx_hash] = true;
        tx_hashes[_transactionID -1] = new_tx_hash;
        ID_to_hash[_transactionID] = new_tx_hash;
    }
}

