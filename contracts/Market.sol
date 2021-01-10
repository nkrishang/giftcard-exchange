/**
 * @authors: [@nkirshang]

 * ERC 792 implementation of a gift card exchange. ( ERC 792: https://github.com/ethereum/EIPs/issues/792 )
 * For the idea, see: https://whimsical.com/crypto-gift-card-exchange-VQTH2F7wE8HMvw3DzcSgRi
 * Neither the code, nor the concept is production ready.

 * SPDX-License-Identifier: MIT
**/



// TO DO:

// - Create storage reference `arbitration` variable wherever `arbitration` state is changed.
// - Modify `withdrawBySeller` (analog: timeOutByBuyer) | Write `withdrawByBuyer` (analog: timeoutBySeller)
// - Write `executeRuling`.
// - Write function / data structure descriptions.
// - General cleanup of contract.



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
    enum DisputeStatus {None, WaitingSeller, WaitingBuyer, Processing, Resolved}
    enum RulingOptions {RefusedToArbitrate, SellerWins, BuyerWins}
    

    struct Transaction {
        uint price;
        bool forSale; // redundant

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
        uint init;

        uint buyerArbitrationFee;
        uint sellerArbitrationFee;
        uint arbitrationFee;

        uint appealRound;

        uint buyerAppealFee;
        uint sellerAppealFee;
        uint appealFee;
        
        Party ruling
    }

    bytes32[] tx_hashes;


    mapping(uint => Arbitration arbitration) public disputeID_to_arbitration; // Necessary?
    mapping(uint => Arbitration) public arbitrations; // Necessary?

    // Transaction level events 
    event TransactionCreated(uint indexed _transactionID, Transaction _transaction, Arbitration _arbitration);
    event TransactionStateUpdate(uint indexed _transactionID, Transaction _transaction);
    event TransactionResolved(uint indexed _transactionID, Transaction _transaction);

    // Dispute level events
    // Dispute from IEvidence
    event DisputeStateUpdate(uint indexed _disputeID, Arbitration _arbitration);

    // Fee Payment reminders
    event HasToPayArbitrationFee(uint indexed transactionID, Party party);
    event HasPaidArbitrationFee(uint indexed transactionID, Party party);

    event HasToPayAppealFee(uint indexed transactionID, Party party);
    event HasPaidAppealFee(uint indexed transactionID, Party party);

    

    constructor(address _arbitrator) { // Flesh out as and when.
        arbitrator = IArbitrator(_arbitrator);
        owner = msg.sender;
    }


    // Contract main functions

    modifier onlyValidTransaction(uint _transactionID, Transaction memory _transaction) {
        require(
            tx_hashes[_transactionID - 1] == hashTransactionState(_transaction), 
            "Transaction doesn't match stored hash."
            );
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

        Arbitration memory arbitration = Arbitration({
            transactionID: _transactionID,
            status: DisputeStatus.None
        });

        bytes32 tx_hash = hashTransactionState(newTransaction);
        tx_hashes.push(tx_hash);
        transactionID = tx_hashes.length;

        emit TransactionCreated(transactionID, transaction, arbitration);
    }


    /**
     * @dev Let's a user buy i.e. engage in the sale of a gift card.
    
     * @param _transactionID The unique ID of the gift card being purchased.
    **/

    function buyCard(
        uint _transactionID,
        Transaction memory _transaction,
        string calldata _metaevidence
    ) external payable OnlyValidTransaction(_transactionID, _transaction) {

        require(_transaction.status == Status.None, "Can't purchase an item already engaged in sale.");
        require(_transaction.forSale, "Cannot purchase item not for sale.");
        require(msg.value == _transaction.price, "Must send exactly the item price.");


        _transaction.status = Status.Pending;
        _transaction.forSale = false;
        _transaction.buyer = msg.sender;
        _transaction.init = block.timestamp;

        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit MetaEvidence(_transactionID, _metaevidence);
    }

    /**
     * @dev Let's the seller withdraw the price amount (if the relevant conditions are met).
     * @param _transactionID The unique ID of the gift card in concern.
    **/

    function withdrawBySeller(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID, _transaction) {

        // Write a succint filter statement later.
        require(msg.sender == _transaction.seller, "Only the seller can withdraw the price of the card.");
        require(block.timestamp - _transaction.init > reclaimPeriod, "Cannot withdraw price while reclaim period is not over.");
        require(transaction.status == Status.Pending, "Can only withdraw price if the transaction is in the pending state.");

        _transaction.status = TransactionStatus.Resolved;

        uint amount = _transaction.locked_price_amount;
        transaction.locked_price_amount = 0;

        msg.sender.call{value: amount};

        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);
        emit TransactionResolved(_transactionID, _transaction);
    }

    function withdrawByBuyer() external {};

    /**
     * @dev Let's the buyer reclaim the price amount (if in the reclaim window) by depositing arbitration fee.
    
     * @param _transactionID The unique ID of the gift card in concern.
    **/


    function reclaimPriceByBuyer(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID _transaction) {

        require(msg.sender == _transaction.buyer, "Only the buyer of the card can reclaim the price paid.");
        require(block.timestamp - _transaction.init < reclaimPeriod, "Cannot reclaim price after the reclaim window is closed.");
        require(_transaction.status == Status.Pending, "Can reclaim price only in pending state.");

        uint arbitrationCost = arbitrator.arbitrationCost(""); // What is passed in for extraData?
        require(msg.value == arbitrationCost, "Must deposit the right arbitration fee to reclaim paid price.");


        _transaction.status = TransactionStatus.Reclaimed;
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        emit HasToPayArbitrationFee(_transactionID, Party.Seller);
    }

    // Seller engage with dispute fn.

    function payArbitrationFeeBySeller(
        uint _transactionID,
        uint _metaevidenceID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) public payable {

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - _arbitration.sellerArbitrationFee), 
            "Must have at least arbitration cost in balance to create dispute."
        );

        if(_transaction.status < Status.Disputed) _arbitration.init = block.timestamp;
        
        _arbitration.arbitrationFee += msg.value;
        _arbitration.sellerArbitrationFee += msg.value;

        if(_arbitration.buyerArbitrationFee < arbitrationCost) {
            _arbitration.status = DisputeStatus.WaitingBuyer;
            emit HasToPayArbitrationFee(_transactionID, Party.Buyer);
        } else {
            raiseDispute(_transactionID, _metaevidenceID, arbitrationCost, _transaction, _arbitration);
        }
    }


    function payArbitrationFeeByBuyer(
        uint _transactionID,
        uint _metaevidenceID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) public payable {

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - _arbitration.sellerArbitrationFee), 
            "Must have at least arbitration cost in balance to create dispute."
        );

        if(_transaction.status < Status.Disputed) _arbitration.init = block.timestamp;
        
        _arbitration.arbitrationFee += msg.value;
        _arbitration.buyerArbitrationFee += msg.value;

        if(_arbitration.sellerArbitrationFee < arbitrationCost) {
            _arbitration.status = DisputeStatus.WaitingSeller;
            emit HasToPayArbitrationFee(_transactionID, Party.Seller);
        } else {
            raiseDispute(_transactionID, _metaevidenceID, arbitrationCost, _transaction, _arbitration);
        }
    }

    // raiseDispute internal function

    function raiseDispute(
        uint _transactionID,
        uint _metaEvidenceID
        uint _arbitrationCost,
        Transaction memory _transaction,
        Arbitration memory _arbitation
        ) internal {

        _transaction.status = TransactionStatus.Disputed;
        _transaction.disputeID = arbitrator.createDispute{value: _arbitrationCost}(numOfRulingOptions, "");
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        _arbitation.status = DisputeStatus.Processing;
        disputeID_to_arbitration[_transaction.disputeID] = _arbitration;

        // Seller | Buyer fee reimbursements.

        if(_arbitation.sellerArbitrationFee > _arbitrationCost) {
            uint extraFee = _arbitation.sellerArbitrationFee - _arbitrationCost;
            _arbitation.sellerArbitrationFee = _arbitrationCost;
            _transaction.seller.call{value: extraFee};
        }

        if(_arbitation.buyerArbitrationFee > _arbitrationCost) {
            uint extraFee = _arbitation.buyerArbitrationFee - _arbitrationCost;
            _arbitation.buyerArbitrationFee = _arbitrationCost;
            _arbitation.buyer.call{value: extraFee};
        }

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit Dispute(arbitrator, _transaction.disputeID, _metaEvidenceID, _transactionID);
    }

    /**
     * @dev Let's the buyer (post reclaim period) / seller appeal a ruling by depositing appeal fee.
    
     * @param _cardID The unique ID of the gift card in concern.
    **/

    function payAppealFeeBySeller(
        uint _transactionID,
        Transaction memory _transaction,
        Arbitration memory _arbitration,
    ) public payable {
        // appeal period start / end checked by calling the arbitrator
        require(_transaction.status >= TransactionStatus.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(transaction.disputeID, "");
        require(msg.value >= appealCost - _arbitration.sellerAppealFee, "Not paying sufficient appeal fee.");

        _arbitration.sellerAppealFee += msg.value;
        _arbitration.appealFee += msg.value;

        if(_arbitration.buyerAppealFee < appealCost) {
            _arbitration.status = DisputeStatus.WaitingBuyer;
            emit HasToPayAppealFee(_transactionID, Party.Buyer);
        } else {
            _arbitration.appealRound++;
            appealTransaction(_transactionID, appealCost, _transaction, _arbitration);
        }
    }

    function payAppealFeeByBuyer(
        uint _transactionID,
        Transaction memory _transaction,
        Arbitration memory _arbitration,
    ) public payable {
        // appeal period start / end checked by calling the arbitrator
        require(_transaction.status >= TransactionStatus.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(transaction.disputeID, "");
        require(msg.value >= appealCost - _arbitration.buyerAppealFee, "Not paying sufficient appeal fee.");

        _arbitration.buyerAppealFee += msg.value;
        _arbitration.appealFee += msg.value;

        if(_arbitration.sellerAppealFee < appealCost) {
            _arbitration.status = DisputeStatus.WaitingSeller;
            emit HasToPayAppealFee(_transactionID, Party.Seller);
        } else {
            _arbitration.appealRound++;
            appealTransaction(_transactionID, appealCost, _transaction, _arbitration);
        }
    }

    function appealTransaction(
        uint _transactionID,
        uint _appealCost,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) internal {

        _transaction.status = Status.Appealed;
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);
        

        _arbitration.appealRound++;
        arbitrator.appeal{value: _appealCost}(_transaction.disputeID, "");
        _arbitration.status = DisputeStatus.Processing;

        // Seller | Buyer fee reimbursements.

        if(_arbitration.sellerAppealFee > _appealCost) {
            uint extraFee = _arbitration.sellerAppealFee - _appealCost;
            _arbitration.sellerAppealFee = _appealCost;
            _transaction.seller.call{value: extraFee};
        }

        if(_arbitration.buyerAppealFee > _appealCost) {
            uint extraFee = _arbitration.buyerAppealFee - _appealCost;
            _arbitration.buyerAppealFee = _appealCost;
            _transaction.buyer.call{value: extraFee};
        }

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit DisputeStateUpdate( _transaction.disputeID, Arbitration _arbitration);
    }

    // Implementation of the rule() function from IArbitrable.
    // Ruling event is directly inherited from IArbitrable.


    function rule(uint256 _disputeID, uint256 _ruling) external override {

        require(msg.sender == address(arbitrator), "Only the arbitrator can give a ruling.");

        
        Arbitration storage arbitration = disputeID_to_arbitration[_disputeID]
        require(arbitration.status == DisputeStatus.Processing, "Can give ruling only when a dispute is in process.");
        arbitration.status = DisputeStatus.Resolved;

        if(_ruling == uint(RulingOptions.BuyerWins)) {
            arbitration.ruling = Party.Buyer;
        }

        if(_ruling == uint(RulingOptions.SellerWins)) {
            arbitration.ruling = Party.Seller;
        }

        if(_ruling == uint(RulingOptions.RefusedToArbitrate)) {
            arbitration.ruling = Party.None;
        }

        emit Ruling(arbitrator, _disputeID, _ruling);
    }

    function executeRuling(
        uint _transactionID,
        Transaction memory _transaction
    ) external OnlyValidTransaction(_transactionID _transaction) {
        
        Arbitration storage _arbitration = disputeID_to_arbitration[_transactionID]; // storage init whenever arbitration state change?
        require(arbitration.status == DisputeStatus.Resolved, "An arbitration must be resolved to execute its ruling.");

        if(_arbitration.ruling == Party.Buyer) {
            //
        }

        if(_arbitration.ruling == Party.Seller) {
            //
        }

        if(_arbitration.ruling == Party.None) {
            //
        }

    };

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

}

