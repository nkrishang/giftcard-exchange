/**
 * Test arbitrator for DGCX

 * DGCX Market contract details: 
 * ERC 792 implementation of a gift card exchange. ( ERC 792: https://github.com/ethereum/EIPs/issues/792 )
 * For the idea, see: https://whimsical.com/crypto-gift-card-exchange-VQTH2F7wE8HMvw3DzcSgRi
 * Neither the code, nor the concept is production ready.

 * SPDX-License-Identifier: MIT
**/

pragma solidity >=0.7;

import "./interface/IArbitrator.sol";

contract TestArbitrator is IArbitrator {
    address public owner = msg.sender;

    uint public _arbitrationCost = 0.1 ether;
    uint public _appealCost = 1 ether;

    uint public testAppealPeriodStart;
    uint public testAppealPeriodEnd;

    struct Dispute {
        IArbitrable arbitrated;
        uint256 choices;
        uint256 ruling;
        DisputeStatus status;
    }

    Dispute[] public disputes;

    function arbitrationCost(bytes memory _extraData) public override view returns (uint256) {
        _extraData = "";
        return _arbitrationCost;
    }

    function appealCost(uint256 _disputeID, bytes memory _extraData) public override view returns (uint256) {
        _extraData = "";
        _disputeID = 0;
        return _appealCost;
    }


    function createDispute(uint256 _choices, bytes memory _extraData)
        public
        override
        payable
        returns (uint256 disputeID)
    {
        require(msg.value >= arbitrationCost(_extraData), "Not enough ETH to cover arbitration costs.");

        disputes.push(
            Dispute({
                arbitrated: IArbitrable(msg.sender),
                choices: _choices,
                ruling: uint256(-1),
                status: DisputeStatus.Waiting
            })
        );

        disputeID = disputes.length - 1;
        emit DisputeCreation(disputeID, IArbitrable(msg.sender));
    }

    function disputeStatus(uint256 _disputeID) public override view returns (DisputeStatus status) {
        status = disputes[_disputeID].status;
    }

    function currentRuling(uint256 _disputeID) public override view returns (uint256 ruling) {
        ruling = disputes[_disputeID].ruling;
    }

    function rule(uint256 _disputeID, uint256 _ruling) public {
        require(msg.sender == owner, "Only the owner of this contract can execute rule function.");

        Dispute storage dispute = disputes[_disputeID];

        require(_ruling <= dispute.choices, "Ruling out of bounds!");
        require(dispute.status == DisputeStatus.Waiting, "Dispute is not awaiting arbitration.");

        dispute.ruling = _ruling;
        dispute.status = DisputeStatus.Solved;

        msg.sender.transfer(arbitrationCost(""));
        dispute.arbitrated.rule(_disputeID, _ruling);
    }

    function appeal(uint256 _disputeID, bytes memory _extraData) public override payable {
        require(msg.value >= appealCost(_disputeID, _extraData), "Not enough ETH to cover arbitration costs.");
    }

    function appealPeriod(uint256 _disputeID) public override view returns (uint256 start, uint256 end) {
        _disputeID = 0;
        return (testAppealPeriodStart, testAppealPeriodEnd);
    }

    // Setter functions

    function setArbitrationCost(uint _newCost) external {
        _arbitrationCost = _newCost;
    }

    function setAppealCost(uint _newCost) external {
        _appealCost = _newCost;
    }

    function setAppealPeriod() external {
        testAppealPeriodStart = block.timestamp;
        testAppealPeriodEnd = block.timestamp + 1 minutes; 
    }
}