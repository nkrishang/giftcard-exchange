# DGCX - Decentralized Gift Card Exchange
## A peer-to-peer gift card marketplace.

DGCX is a platform to buy and sell gift cards online. Transactions between buyers and sellers are based on an escrow smart contract. Any disputes from either party will be handled by [Kleros.io](https://kleros.io/). The DGCX application will function to facilitate valid online gift card transactions by: 

1. arbitrating disputes using a decentralized protocol like [Kleros.io](https://kleros.io/)
2. requiring all parties to comply with an evidence submission user flow that makes it very costly for disingenuous parties to lie, cheat or exit-scam.

### How it all works - example scenario
1. Alice has a $50 Target Gift Card... she doesn't live near a Target so she decides to sell on DGCX (because she is fearful of getting scammed on r/giftcardexchange).
- Alice lists her $50 Target GC on DGCX which she wants to sell for $40 worth of ETH.
- To list the card, Alice must follow the evidence submission flow on the DGCX UI. This ensures that Alice's card indeed has the claimed balance at the time of listing. 

2. Bob shops at Target all the time! He sees Alice's $50 Gift Card offer and selects it from the UI. He is then required to deposit the price of the card i.e. $40 worth of ETH into the DGCX escrow smart contract.
- To purchase the card, Bob must follow the evidence submission flow on the DGCX UI. This ensures that the purchased card indeed has the claimed balance at the time of sale.
- Bob receives the gift card information upon depositing the price. He may then verify the balance of the gift card he has purchased.

3. If both parties played fair, the arbitration period ends and:
- Bob bought a $50 Target Gift Card at a 20% discount.
- Alice liquidated her Target Gift Card and receives Bob's payment (she is able to withdraw the gift card price from the DGCX contract).

4. If either party attempts a scam, the buyer or seller can choose to dispute within the arbitration period -> this brings the case in front of the decentralized Kleros court which will delegate based on standardized evidence.
- At the time of purchase, Bob gets a 6 hour reclaim window, which starts as soon as he purchases the gift card. Within that window, Bob may dispute the transaction by depositing an arbitration fee, determined by Kleros, the arbitrator.
- To respond to the dispute, Alice must deposit the arbitration fee in the DGCX contract within the fee deposit period of 1 day (started when Bob deposits his fee).
- If Alice does not respond in time, Bob is reimbursed his arbitration fee and the price of the gift card. No Kleros dispute is called.
- If Alice responds to the dispute, a dispute is created in the Kleros arbitrator contract. The winner of the arbitration is reimbursed their arbitration fee plus the price of the gift card.


### The Why

[I](https://github.com/AlvaroLuken/giftcard-exchange), was **SCAMMED**. For context: I received a $50 Amazon gift card over the holidays. Seeing as I don't really use Amazon, I went online to see what my options were... that is when I stumbled onto the [GCX subreddit](https://www.reddit.com/r/giftcardexchange/) - the idea seemed pretty straightforward: trade your gift card with other Redditors! So I posted my offer in their required format: [H] Amazon $50 GC [W] $40 in ETH... H = Have ; W = Want... 

Minutes later, I was reached out to by scammer-punk-ass [mattyfc](https://www.reddit.com/user/mattyfc/)... after 2 hours of chatting back on forth on Reddit's clunky messaging platform, he asked if I could go first seeing as I had the lower Reddit karma score and account age - I obliged and _surprise, surprise_ he all of a sudden stopped answering and was never to be seen again... the dood just plain ran off with my Amazon $50 as if I had just handed it to him on the street. 

So back to _The Why_... in the next section called **The Problem We Solve**:


### The Problem We Solve

Currently, no viable options exist where a user can securely transact an off-chain asset like a gift card in exchange for payment in on-chain assets like BTC/ETH because:

1. **Trust**: It is difficult to establish peer-to-peer trust on current platforms (ie, how do I know all parties will play by the rules)
2. **Atomicity**: Alice must go first, leaving her vulnerable if Bob decides to exit. And vice-versa.
3. **Privacy** : Centralized options harvest your data and offer no significant functionality/discount boost.
4. **Functionality**: General platforms are adapted to meet ultra-specific UI needs... just like Reddit being clunkily adapted to be the world's main platform for peer-to-peer gift card exchanges.


### Extra Features
These are features that we also solve for online gift card transacting, but we will place them in the Extra Features section because we think of security first (so that no one else is ever scammed again)... everything else comes next:

1. **Liquidity**: DGCX provides liquidity to gift card holders, doomed to spend their value only at one specific place... think about it this way: 
- If you receive a gift card for a place you don't like, that is dead money on arrival. You can either re-gift your gift card to someone else or force yourself to purchase something from the place...
2. **Arbitration**: When I was scammed, I reached out to the GCX subreddit mods and was... plainly ignored - what can they do anyway? DGCX offers Kleros arbitration, an online decentralized court protocol + specifically-designed UI that will provide a smooth option for either buyer or seller to dispute their case, should it be necessary. So rest assured, if you are an honest person using DGCX, you have _NOTHING_ to fear.
3. MORE TBD



### Current competitors vs. DGCX

| Current Options  | DGCX |
| ------------- |:-------------:|
| Buyers and sellers left vulnerable to scams - no trust/confidence model available     | Collateral establishes shared risk for buyer/seller |
| Arbitration is non-existent | Kleros decentralized arbitration  |
| Data harvesting    | only MetaMask needed |
|Current platforms offer only clunky non-specific UI solutions| Specific UI for trusted exchange with decentralized arbitration |
