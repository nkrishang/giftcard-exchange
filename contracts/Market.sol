/**
 * @authors: [@nkirshang]

 * ERC 792 implementation of a gift card exchange. ( ERC 792: https://github.com/ethereum/EIPs/issues/792 )
 * For the idea, see: https://whimsical.com/crypto-gift-card-exchange-VQTH2F7wE8HMvw3DzcSgRi
 * Neither the code, nor the concept is production ready.

 * SPDX-License-Identifier: MIT
**/

import "./IArbitrable.sol";
import "./IArbitrator.sol";
import "./IEvidence.sol";

pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

contract Market is IArbitrable, IEvidence {

    //====== Contract state variables. ======

    address public owner;
    IArbitrator public arbitrator;

    uint arbitrationFeeDepositPeriod = 1 days; // For testing, change to: 1 minutes.
    uint reclaimPeriod = 6 hours; // For testing, change to: 1 minutes
    uint numOfRulingOptions = 2;



    //===== Data structures for the contract. =====

    enum Party {None, Buyer ,Seller}
    enum Status {None, Pending, Disputed, Appealed, Resolved}
    enum DisputeStatus {None, WaitingSeller, WaitingBuyer, Processing, Resolved}
    enum RulingOptions {RefusedToArbitrate, BuyerWins, SellerWins}

    // Transaction level events 
    event TransactionStateUpdate(uint indexed _transactionID, Transaction _transaction);
    event TransactionResolved(uint indexed _transactionID, Transaction _transaction);

    // Dispute level events (not defined in inherited interfaces)
    event DisputeStateUpdate(uint indexed _disputeID, uint indexed _transactionID, Arbitration _arbitration);

    // Fee Payment notifications 
    event HasToPayArbitrationFee(uint indexed transactionID, Party party);
    event HasToPayAppealFee(uint indexed transactionID, Party party);
    

    struct Transaction {
        uint price;
        bool forSale;

        address payable seller;
        address payable buyer;
        bytes32 cardInfo_URI_hash;

        Status status;
        uint init;

        uint disputeID;
    }

    struct Arbitration {
        
        uint transactionID;
        DisputeStatus status;
        uint feeDepositDeadline;

        uint buyerArbitrationFee;
        uint sellerArbitrationFee;
        uint arbitrationFee;

        uint appealRound;

        uint buyerAppealFee;
        uint sellerAppealFee;
        uint appealFee;
        
        Party ruling;
    }

    bytes32[] public tx_hashes;

    mapping(uint => Arbitration) public disputeID_to_arbitration;

    constructor(address _arbitrator) {
        arbitrator = IArbitrator(_arbitrator);
        owner = msg.sender;
    }


    // Contract main functions

    modifier OnlyValidTransaction(uint _transactionID, Transaction memory _transaction) {
        require(
            tx_hashes[_transactionID - 1] == hashTransactionState(_transaction), 
            "Transaction doesn't match stored hash."
            );
        _;
    }

    
    //========== Contract functions ============

    // Allows a seller to list a gift card.
    function listNewCard(bytes32 _cardInfo, uint _price) external {

        Transaction memory transaction = Transaction({
            price: _price,
            forSale: true,

            seller: msg.sender,
            buyer: address(0x0),
            cardInfo_URI_hash: _cardInfo,

            status: Status.None,

            init: 0,

            disputeID: 0 
        });

        bytes32 tx_hash = hashTransactionState(transaction);
        tx_hashes.push(tx_hash);
        uint transactionID = tx_hashes.length;

        event TransactionStateUpdate(transactionID, transaction);
    }

    // Allows a buyer to engage in the sale of a gift card.
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

    // Allows buyer to get the (hash of) URI containing gift card information.
    function getCardInfo (
        uint _transactionID,
        Transaction memory _transaction
    ) external view OnlyValidTransaction(_transactionID, _transaction)  returns (bytes32 _cardInfo) {

        require(_transaction.buyer == msg.sender, "Only the buyer can retrieve item info.");
        _cardInfo = _transaction.cardInfo_URI_hash;
    }


    // Allows seller to withdraw price from escrow (Case: no disputes raised.)
    function withdrawPriceBySeller(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID, _transaction) {

        // Write a succint filter statement later.
        require(msg.sender == _transaction.seller, "Only the seller can call a seller-withdraw function.");
        require(block.timestamp - _transaction.init > reclaimPeriod, "Cannot withdraw price while reclaim period is not over.");
        require(_transaction.status == Status.Pending, "Can only withdraw price if the transaction is in the pending state.");

        _transaction.status = Status.Resolved;

        uint amount = _transaction.price;
        msg.sender.call{value: amount};

        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);
        emit TransactionResolved(_transactionID, _transaction);
    }

    // Allows buyer to withdraw price + fees from escrow (Case: dispute raised; appeal possibly raised)
    function withdrawPriceByBuyer(
        uint _transactionID,
        Transaction memory _transaction
        ) external OnlyValidTransaction(_transactionID, _transaction) {
        
        Arbitration storage arbitration = disputeID_to_arbitration[_transaction.disputeID];

        require(msg.sender == _transaction.buyer, "Only the buyer can call a buyer-withdraw function.");
        require(
            _transaction.status >= Status.Disputed,
            "This function is called only when the seller's payment of the arbitration fee times out."
        );
        require(block.timestamp > arbitration.feeDepositDeadline, "The seller still has time to deposit an arbitration fee.");

        if(arbitration.appealRound != 0) {
            (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(_transaction.disputeID);
            require(
                block.timestamp >= appealPeriodStart && block.timestamp > appealPeriodEnd, 
                "Seller still has time to fund an appeal."
            );
        }
        arbitration.status = DisputeStatus.Resolved;

        uint refundAmount = _transaction.price;
        refundAmount += (arbitration.buyerArbitrationFee + arbitration.buyerAppealFee);
        msg.sender.call{value: refundAmount};

        emit TransactionResolved(_transactionID, _transaction);
    }       
  

    // Allows buyer to raise a dispute - must be raised within the recalim window - buyer must deposit arbitration fee.
    function reclaimDisputeByBuyer(
        uint _transactionID,
        Transaction memory _transaction
        ) external payable OnlyValidTransaction(_transactionID, _transaction) {

        require(msg.sender == _transaction.buyer, "Only the buyer of the card can raise a reclaim dispute.");
        require(block.timestamp - _transaction.init < reclaimPeriod, "Cannot reclaim price after the reclaim window is closed.");
        require(_transaction.status == Status.Pending, "Can raise a reclaim dispute pending state.");

        uint arbitrationCost = arbitrator.arbitrationCost(""); // What is passed in for extraData?
        require(msg.value >= arbitrationCost, "Must deposit the right arbitration fee to reclaim paid price.");

        Arbitration memory arbitration = Arbitration({
            transactionID: _transactionID,
            status: DisputeStatus.WaitingSeller,
            feeDepositDeadline: block.timestamp + arbitrationFeeDepositPeriod,

            buyerArbitrationFee: msg.value,
            sellerArbitrationFee: 0,
            arbitrationFee: msg.value,

            appealRound: 0,

            buyerAppealFee: 0,
            sellerAppealFee: 0,
            appealFee: 0,
            
            ruling: Party.None
        });

        _transaction.status = Status.Disputed;
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        uint noDisputeID = 0;

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit DisputeStateUpdate(noDisputeID, _transactionID, arbitration);
        emit HasToPayArbitrationFee(_transactionID, Party.Seller);
    }

    // Allows seller to engage with the buyer-raised dispute - must be raised before the fee deposit deadline - must pay arbitration fee.
    function payArbitrationFeeBySeller(
        uint _transactionID,
        uint _metaevidenceID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) public payable OnlyValidTransaction(_transactionID, _transaction) {

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - _arbitration.sellerArbitrationFee), 
            "Must have at least arbitration cost in balance to create dispute."
        );
        require(msg.sender == _transaction.seller, "Only the seller involved in the dispute can pay the seller's fee.");
        require(block.timestamp < _arbitration.feeDepositDeadline, "The arbitration fee deposit period is over.");
        require(_arbitration.status == DisputeStatus.WaitingSeller,
            "Can only pay deposit fee when its the seller's turn to respond."
        );
        
        _arbitration.arbitrationFee += msg.value;
        _arbitration.sellerArbitrationFee += msg.value;
        _arbitration.feeDepositDeadline = block.timestamp + arbitrationFeeDepositPeriod;

        if(_arbitration.buyerArbitrationFee < arbitrationCost) {
            _arbitration.status = DisputeStatus.WaitingBuyer;
            emit DisputeStateUpdate(_transaction.disputeID, _transactionID, _arbitration);
            emit HasToPayArbitrationFee(_transactionID, Party.Buyer);
        } else {
            raiseDispute(_transactionID, _metaevidenceID, arbitrationCost, _transaction, _arbitration);
        }
    }

    // Allows buyer to pay remaining arbitration fees. (Case: arbitration cost was higher when seller deposited fee)
    function payArbitrationFeeByBuyer(
        uint _transactionID,
        uint _metaevidenceID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) public payable OnlyValidTransaction(_transactionID, _transaction) {

        uint arbitrationCost = arbitrator.arbitrationCost("");
        require(
            msg.value >= (arbitrationCost - _arbitration.sellerArbitrationFee), 
            "Must have at least arbitration cost in balance to create dispute."
        );
        require(block.timestamp < _arbitration.feeDepositDeadline, "The arbitration fee deposit period is over.");
        require(msg.sender == _transaction.buyer, "Only the buyer involved in the dispute can pay the buyer's fee.");
        require(_arbitration.status == DisputeStatus.WaitingBuyer,
            "Can only pay deposit fee when its the buyer's turn to respond."
        );
        
        _arbitration.arbitrationFee += msg.value;
        _arbitration.buyerArbitrationFee += msg.value;
        _arbitration.feeDepositDeadline = block.timestamp + arbitrationFeeDepositPeriod;

        if(_arbitration.sellerArbitrationFee < arbitrationCost) {
            _arbitration.status = DisputeStatus.WaitingSeller;
            emit DisputeStateUpdate(_transaction.disputeID, _transactionID, _arbitration);
            emit HasToPayArbitrationFee(_transactionID, Party.Seller);
        } else {
            raiseDispute(_transactionID, _metaevidenceID, arbitrationCost, _transaction, _arbitration);
        }
    }


    // Calls the arbitrator contract to create a dispute - internally called - no checks
    function raiseDispute(
        uint _transactionID,
        uint _metaEvidenceID,
        uint _arbitrationCost,
        Transaction memory _transaction,
        Arbitration memory _arbitration
        ) internal {

        _transaction.status = Status.Disputed;
        _transaction.disputeID = arbitrator.createDispute{value: _arbitrationCost}(numOfRulingOptions, "");
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        _arbitration.status = DisputeStatus.Processing;
        disputeID_to_arbitration[_transaction.disputeID] = _arbitration;

        // Seller | Buyer fee reimbursements.

        if(_arbitration.sellerArbitrationFee > _arbitrationCost) {
            uint extraFee = _arbitration.sellerArbitrationFee - _arbitrationCost;
            _arbitration.sellerArbitrationFee = _arbitrationCost;
            _transaction.seller.call{value: extraFee};
        }

        if(_arbitration.buyerArbitrationFee > _arbitrationCost) {
            uint extraFee = _arbitration.buyerArbitrationFee - _arbitrationCost;
            _arbitration.buyerArbitrationFee = _arbitrationCost;
            _transaction.buyer.call{value: extraFee};
        }

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit Dispute(arbitrator, _transaction.disputeID, _metaEvidenceID, _transactionID);
    }

    // Allows buyer to pay appeal fee - must be paid in the appeal window set by arbitrator.
    function payAppealFeeBySeller(
        uint _transactionID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
    ) public payable OnlyValidTransaction(_transactionID, _transaction) {

        require(_transaction.status >= Status.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(_transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(_transaction.disputeID, "");
        require(msg.value >= appealCost - _arbitration.sellerAppealFee, "Not paying sufficient appeal fee.");

        _arbitration.sellerAppealFee += msg.value;
        _arbitration.appealFee += msg.value;

        if(_arbitration.buyerAppealFee < appealCost) {
            _arbitration.status = DisputeStatus.WaitingBuyer;
            emit DisputeStateUpdate( _transaction.disputeID, _transactionID, _arbitration);
            emit HasToPayAppealFee(_transactionID, Party.Buyer);
        } else {
            _arbitration.appealRound++;
            appealTransaction(_transactionID, appealCost, _transaction);
        }
    }

    // Allows buyer to pay appeal fee - must be paid in the appeal window set by arbitrator.
    function payAppealFeeByBuyer(   
        uint _transactionID,
        Transaction memory _transaction,
        Arbitration memory _arbitration
    ) public payable OnlyValidTransaction(_transactionID, _transaction) {

        require(_transaction.status >= Status.Disputed, "There is no dispute to appeal.");

        (uint256 appealPeriodStart, uint256 appealPeriodEnd) = arbitrator.appealPeriod(_transaction.disputeID);
        require(
            block.timestamp >= appealPeriodStart && block.timestamp < appealPeriodEnd, 
            "Funding must be made within the appeal period."
        );

        uint256 appealCost = arbitrator.appealCost(_transaction.disputeID, "");
        require(msg.value >= appealCost - _arbitration.buyerAppealFee, "Not paying sufficient appeal fee.");

        _arbitration.buyerAppealFee += msg.value;
        _arbitration.appealFee += msg.value;

        if(_arbitration.sellerAppealFee < appealCost) {
            _arbitration.status = DisputeStatus.WaitingSeller;
            emit DisputeStateUpdate( _transaction.disputeID, _transactionID, _arbitration);
            emit HasToPayAppealFee(_transactionID, Party.Seller);
        } else {
            _arbitration.appealRound++;
            appealTransaction(_transactionID, appealCost, _transaction);
        }
    }

    // Calls the arbitrator contract to create an appeal - internally called - no checks
    function appealTransaction(
        uint _transactionID,
        uint _appealCost,
        Transaction memory _transaction
        ) internal {

        _transaction.status = Status.Appealed;
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);
        
        Arbitration storage arbitration = disputeID_to_arbitration[_transaction.disputeID];

        arbitration.appealRound++;
        arbitrator.appeal{value: _appealCost}(_transaction.disputeID, "");
        arbitration.status = DisputeStatus.Processing;

        // Seller | Buyer fee reimbursements.

        if(arbitration.sellerAppealFee > _appealCost) {
            uint extraFee = arbitration.sellerAppealFee - _appealCost;
            arbitration.sellerAppealFee = _appealCost;
            _transaction.seller.call{value: extraFee};
        }

        if(arbitration.buyerAppealFee > _appealCost) {
            uint extraFee = arbitration.buyerAppealFee - _appealCost;
            arbitration.buyerAppealFee = _appealCost;
            _transaction.buyer.call{value: extraFee};
        }

        emit TransactionStateUpdate(_transactionID, _transaction);
        emit DisputeStateUpdate( _transaction.disputeID, _transactionID, arbitration);
    }

    // Called by the arbitrator contract to give a ruling on a dispute - see IArbitrable i.e. ERC 792 Arbitrable interface.
    function rule(uint256 _disputeID, uint256 _ruling) external override {

        require(msg.sender == address(arbitrator), "Only the arbitrator can give a ruling.");

        
        Arbitration storage arbitration = disputeID_to_arbitration[_disputeID];
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

    // Executes the ruling given by the arbitrator
    function executeRuling(
        uint _transactionID,
        uint _disputeID,
        Transaction memory _transaction
    ) external OnlyValidTransaction(_transactionID, _transaction) {
        
        Arbitration storage arbitration = disputeID_to_arbitration[_disputeID]; // storage init whenever arbitration state change?
        require(arbitration.status == DisputeStatus.Resolved, "An arbitration must be resolved to execute its ruling.");

        uint refundAmount = _transaction.price;

        if(arbitration.ruling == Party.Buyer) {
            refundAmount += arbitration.buyerArbitrationFee;
            refundAmount += arbitration.buyerAppealFee;

            console.log(refundAmount);
            _transaction.buyer.transfer(refundAmount);
        }

        if(arbitration.ruling == Party.Seller) {
            refundAmount += arbitration.sellerArbitrationFee;
            refundAmount += arbitration.sellerAppealFee;

            _transaction.seller.transfer(refundAmount);
        }

        if(arbitration.ruling == Party.None) {
            refundAmount += arbitration.sellerArbitrationFee;
            refundAmount += arbitration.sellerAppealFee;

            _transaction.seller.transfer((refundAmount)/2);
            _transaction.buyer.transfer((refundAmount)/2);
        }
        
        _transaction.status = Status.Resolved;
        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        emit TransactionResolved(_transactionID, _transaction);
    }

    // Allows either party of a transaction to submit evidence whether or not a dispute has been raised.
    function submiteEvidence(
        uint _transactionID,
        Transaction memory _transaction,
        string calldata _evidence
    ) public OnlyValidTransaction(_transactionID, _transaction) {

        require(
            msg.sender == _transaction.seller || msg.sender == _transaction.buyer,
            "The caller must be the seller or the buyer."
        );
        require(
            _transaction.status < Status.Resolved,
            "Must not send evidence if the dispute is resolved."
        );

        emit Evidence(arbitrator, _transactionID, msg.sender, _evidence);
    }

    // Setter functions for contract state variables.
 
    function setReclaimationPeriod(uint _newReclaimPeriod) external {
        require(msg.sender == owner, "Only the owner of the contract can change reclaim period.");
        reclaimPeriod = _newReclaimPeriod;
    }

    function setArbitrationFeeDepositPeriod(uint _newFeeDepositPeriod) external {
        require(msg.sender == owner, "Only the owner of the contract can change arbitration fee deposit period.");
        arbitrationFeeDepositPeriod = _newFeeDepositPeriod;
    }

    function setCardPrice(uint _transactionID, Transaction memory _transaction, uint _newPrice) external {
        require(msg.sender == _transaction.seller, "Only the owner of a card can set its price.");
        require(_transaction.status == Status.None, "Can't change gift card price once it has been engaged in sale.");
        _transaction.price = _newPrice;

        tx_hashes[_transactionID -1] = hashTransactionState(_transaction);

        emit TransactionStateUpdate(_transactionID, _transaction);
    }

    // Utility functions

    function hashTransactionState(Transaction memory _transaction) public pure returns (bytes32) {
        
        // Hash the whole transaction

        return keccak256(
            abi.encodePacked(
                _transaction.price,
                _transaction.forSale,

                _transaction.seller,
                _transaction.buyer,
                _transaction.cardInfo_URI_hash,

                _transaction.status,
                _transaction.init,

                _transaction.disputeID
            )
        );
    }

}

