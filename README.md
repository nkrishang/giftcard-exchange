# Gifti.io
## A peer-to-peer gift card marketplace.

Gifti.io is a platform to buy and sell gift cards, or "**Giftis**", online. Transactions between buyers and sellers are based on an escrow smart contract. Any disputes from either party will be handled by [Kleros.io](https://kleros.io/). The Gifti.io infrastructure will function to facilitate valid online gift card transactions by, among other features,: 

1. arbitrating disputes using the decentralized juror protocol [Kleros.io](https://kleros.io/).
2. requiring all parties to comply with an evidence submission user flow that makes it very costly for malicious parties to lie, cheat or exit-scam.

### How it all works - example scenario

#### Listing a gift card for sale.
1. Alice has a $50 Target Gift Card. She doesn't usually shop at Target so she decides to sell it on Gifti.io (because she is fearful of getting scammed on [r/giftcardexchange](https://www.reddit.com/r/giftcardexchange/)).
- Alice lists her $50 Target GC on Gifti.io for a sale price of $40 worth of ETH.
- Alice's Gifti is officially listed. Yay!

#### Buying a gift card.
2. Bob shops at Target all the time! He sees Alice's $50 Gift Card (on sale for $40) offer and selects it from the UI.
- To purchase the card, Bob must follow the evidence submission standards on the Gifti.io UI. **All buyers** will be required to upload a screen recording of the live redemption of their purchased gift card claim code. Further details in **Uploading Buyer Evidence** section.
- While Bob's screen-recording software is activated, Bob is finally shown the Gifti claim code and is then instructed to redeem the code in the retailer's website live. In case the purchased gift card claim code is invalid, [like this sample Amazon one](https://imgur.com/a/5OG9jIq), Bob now has the tangible evidence, via his screen-recording, that he needs to inititate a dispute within the arbitration period and get his money refunded. If the card is valid, Bob does NOT need to submit the screen recording.

#### No disputes case
3. If both parties played fair, the arbitration period ends and:
- Bob bought a $50 Target Gift Card at a 20% discount.
- Alice liquidated her Target Gift Card and receives Bob's payment in ETH (she is able to withdraw the gift card price from the Gifti.io contract).

#### In case of a dispute
4. If either party attempts a scam, the buyer or seller can choose to dispute within the arbitration period -> this brings the case in front of the decentralized Kleros court which will delegate based on Gifti.io's standardized evidence protocols.
- Once the Gifti claim code is revealed to Bob, a 6_hour_reclaim_window countdown begins. Within that window, Bob may dispute the transaction by depositing an arbitration fee, determined by Kleros, the arbitrator.
- To respond to the dispute, Alice must deposit the arbitration fee in the Gifti.io contract within the arbitration_fee_deposit_period of 1 day (started when Bob deposits his fee).
- If Alice does not respond in time, Bob is reimbursed his arbitration fee and the price of the gift card. No Kleros dispute is called.
- If Alice responds to the dispute, a dispute is created in the Kleros arbitrator contract. The winner of the arbitration is reimbursed their arbitration fee plus the price of the gift card.
- A ruling given on a dispute can be appealed by either party involved by depositing an appeal fee within the appeal_fee_deposit_period set by Kleros. The appeal fee increases exponentially for each subsequent ruling to deter a malicious party from continuing to appeal an unfavourable ruling.


#### Further details on buyer evidence submission:
- Remember: **ALWAYS screen record when you redeem a Gifti claim code!**
- The screen recording file should be around 30-60 seconds in length.


## Technical

The repo is a [hardhat](https://hardhat.org/) project. To run the tests - 
- Clone the repo by running `git clone https://github.com/nkrishang/giftcard-exchange` in the terminal.
- Run `npm install` to install the project dependencies.
- Run `npx hardhat test [path of test file]` to run the desired tests.

`Market.sol` is the main smart contract of the platform. It is an [ERC 792](https://developer.kleros.io/en/latest/index.html) and [ERC 1497](https://developer.kleros.io/en/latest/erc-1497.html) compliant arbitrable escrow contract.

`SimpleCentralizedArbitrator.sol` is an [ERC 792](https://developer.kleros.io/en/latest/index.html) compliant arbitrator contract. This contract acts as the arbitrator for `Market.sol` in the tests. In production, the arbitrable contract `Market.sol` will set the [Kleros arbitrator contract on mainnet](https://etherscan.io/address/0x988b3a538b618c7a603e1c11ab82cd16dbe28069#code). 
