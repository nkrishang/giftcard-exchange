
// https://gifti.io

// This contract is for Hardhat testing only.
// In production the arbitrable Market contract will set the KlerosLiquid Arbitrator contract as its arbitrator.

//SPDX-License-Identifier: MIT

pragma solidity >=0.7;

import "./interface/IArbitrator.sol";

contract SimpleCentralizedArbitrator is IArbitrator {
    address public owner = msg.sender;

    bool public called; // test variable
    uint testAppealPeriodStart;
    uint testAppealPeriodEnd;

    struct Dispute {
        IArbitrable arbitrated;
        uint256 choices;
        uint256 ruling;
        DisputeStatus status;
    }

    Dispute[] public disputes;

    function arbitrationCost(bytes memory _extraData) public override view returns (uint256) {
        _extraData = ""; // dummy statement
        if(!(called)) return 1 ether;
        if(called) return 2 ether;
    }

    function changeCalled() external { // test function
        require(msg.sender == owner, "Only owner");
        called = true;
    }

    function appealCost(uint256 _disputeID, bytes memory _extraData) public override pure returns (uint256) {
        _disputeID = 0; // dummy statement
        _extraData = ""; // dummy statement
        return 25 ether; // An unaffordable amount which practically avoids appeals.
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
        _disputeID = 0; // dummy statement
        return (testAppealPeriodStart,testAppealPeriodEnd);
    }

    function setAppealPeriod() external {
        testAppealPeriodStart = block.timestamp;
        testAppealPeriodEnd = block.timestamp + 1 minutes; 
    }
}