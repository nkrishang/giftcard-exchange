# DGCX - Decentralized Gift Card Exchange
## A peer-to-peer gift card marketplace.


### The What
DGCX is a platform to buy and sell gift cards online. Transactions between buyers and sellers are based on an escrow smart contract. If there are ever any disputes from either the buyer, the seller or both, they will be handled by [Kleros.io](https://kleros.io/). The DGCX application will function to facilitate valid online gift card transactions by: 

1. requiring all parties to collateralize an equal amount in ETH to what they intend to buy/sell
2. arbitrating disputes using a decentralized protocol like [Kleros.io](https://kleros.io/)
3. implementing security into the DGCX user interface that makes it very difficult for either buyer or seller to lie, cheat or exit-scam (without getting caught).


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


### The How

1. Alice has a $50 Target Gift Card... she doesn't live near a Target so she decides to sell on DGCX (because she is fearful of getting scammed on GCX)
- Alice lists her $50 Target GC onto the DGCX application, which requires her to stake an amount equal to her Gift Card offer value... she will sell it for $40 so she collateralizes $40 worth of ETH...
- Alice's Target Gift Card is now listed! YAY :)

2. Bob shops at Target all the time! He sees Alice's $50 Gift Card offer, at a 20% discount, and selects it from the UI... he is then required to deposit $40 worth of ETH... Bob purchases and receives the gift card.

3. If both parties played fair, the arbitration period ends and:
- Bob bought a $50 Target Gift Card at a 20% discount.
- Alice liquidated her Target Gift Card and receives Bob's payment (and her collateral is liberated back to her DGCX account).

4. If either party attempts a scam, the buyer or seller can choose to dispute within the arbitration period -> this brings the case in front of the decentralized Kleros court which will delegate based on standardized evidence; the courts will make a decision and the collateral of the attempted-scammer party will be liberated to the victim party.



### Current competitors vs. DGCX

| Current Options  | DGCX |
| ------------- |:-------------:|
| Buyers and sellers left vulnerable to scams - no trust/confidence model available     | Collateral establishes shared risk for buyer/seller |
| Arbitration is non-existent | Kleros decentralized arbitration  |
| Data harvesting    | only MetaMask needed |
|Current platforms offer only clunky non-specific UI solutions| Specific UI for trusted exchange with decentralized arbitration |
