# DGCX - Decentralized Gift Card Exchange
## A peer-to-peer gift card marketplace.

DGCX is a platform to buy and sell gift cards online. Transactions between buyers and sellers are based on an escrow smart contract. Any disputes from either party will be handled by [Kleros.io](https://kleros.io/). The DGCX application will function to facilitate valid online gift card transactions by: 

1. arbitrating disputes using a decentralized protocol like [Kleros.io](https://kleros.io/)
2. requiring all parties to comply with an evidence submission user flow that makes it very costly for malicious parties to lie, cheat or exit-scam.

### How it all works - example scenario

#### Listing a gift card for sale.
1. Alice has a $50 Target Gift Card... she doesn't live near a Target so she decides to sell on DGCX (because she is fearful of getting scammed on r/giftcardexchange).
- Alice lists her $50 Target GC on DGCX which she wants to sell for $40 worth of ETH.
- To list the card, Alice must follow the evidence submission flow on the DGCX UI. This ensures that Alice's card indeed has the claimed balance at the time of listing. 

#### Buying a gift card.
2. Bob shops at Target all the time! He sees Alice's $50 Gift Card offer and selects it from the UI. He is then required to deposit the price of the card i.e. $40 worth of ETH into the DGCX escrow smart contract.
- To purchase the card, Bob must follow the evidence submission flow on the DGCX UI. This ensures that the purchased card indeed has the claimed balance at the time of sale.
- Bob receives the gift card information upon depositing the price. He may then verify the balance of the gift card he has purchased.

#### No disputes case
3. If both parties played fair, the arbitration period ends and:
- Bob bought a $50 Target Gift Card at a 20% discount.
- Alice liquidated her Target Gift Card and receives Bob's payment (she is able to withdraw the gift card price from the DGCX contract).

#### In case of a dispute
4. If either party attempts a scam, the buyer or seller can choose to dispute within the arbitration period -> this brings the case in front of the decentralized Kleros court which will delegate based on standardized evidence.
- At the time of purchase, Bob gets a 6 hour reclaim window, which starts as soon as he purchases the gift card. Within that window, Bob may dispute the transaction by depositing an arbitration fee, determined by Kleros, the arbitrator.
- To respond to the dispute, Alice must deposit the arbitration fee in the DGCX contract within the fee deposit period of 1 day (started when Bob deposits his fee).
- If Alice does not respond in time, Bob is reimbursed his arbitration fee and the price of the gift card. No Kleros dispute is called.
- If Alice responds to the dispute, a dispute is created in the Kleros arbitrator contract. The winner of the arbitration is reimbursed their arbitration fee plus the price of the gift card.
- A ruling given on a dispute can be appealed by either party invovled by depositing an appeal fee within a appeal fee deposit period set by Kleros. The appeal fee increases exponentially for each subsequent ruling to deter a malicious party from continuing to appeal an unfavourable ruling.

## Technical

The repo is a [hardhat](https://hardhat.org/) project. To run the tests - 
- Clone the repo by running `git clone https://github.com/nkrishang/giftcard-exchange` in the terminal.
- Run `npm install` to install the project dependencies.
- Run `npx hardhat test [path of test file]` to run the desired tests.

`Market.sol` is the main smart contract of the platform. It is an [ERC 792](https://developer.kleros.io/en/latest/index.html) and [ERC 1497](https://developer.kleros.io/en/latest/erc-1497.html) compliant arbitrable escrow contract.

`SimpleCentralizedArbitrator.sol` is an [ERC 792](https://developer.kleros.io/en/latest/index.html) compliant arbitrator contract. This contract acts as the arbitrator for `Market.sol` in the tests. In production, the arbitrable contract `Market.sol` will set the [Kleros arbitrator contract on mainnet](https://etherscan.io/address/0x988b3a538b618c7a603e1c11ab82cd16dbe28069#code). 
