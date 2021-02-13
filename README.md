# marginswap-core
Core contracts for marginswap functionality


## Disclaimer

This is very work in progress, it is untested. It will have bugs. Do not let this touch real money. It is a prototype of functionality.

## Code structure

`contracts/MarginTrading.sol` is perhaps the most interesting. `contracts/MarginRouter.sol` is the entry point for all trading. `contracts/Admin` is where the staking happens both for fees and margin calling. `contracts/Fund.sol` holds all the cash.
`contracts/Lending` manages spot and bond lending though this will likely be factored out into its own repo.

Work in progress parts:
* Margin calling (particularly punishing faithless stakers)
* Fee distribution
* Reworking the bond structure
* Insurance
* Price tracking
* Incentive distribution

## Rationale

We have gone for a relatively modular approach which should make it easy for governance to switch out / update parts of the logic. Also, funds are kept at arm's length from functionality.

There is to be no constantly-updating oracle or gas-costly block-wise auctions for token holders.
