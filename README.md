# marginswap-core
Core contracts for marginswap functionality


## Disclaimer

This is very work in progress, it is untested. It will have bugs. Do not let this touch real money. It is a prototype of functionality.

## Code structure

`contracts/MarginTrading.sol` is perhaps the most interesting, followed by `Lending.sol`. Missing pieces:
* The router (taking fees and connecting to uniswap / sushiswap for now -- will be a modified copy of uniswap router v2)
* Margin call staking contract
* Facilities to get state in and out, as well as hooks for future plugins (to be controlled by the simple roles system)

## Rationale

We have gone for a relatively modular approach which should make it easy for governance to switch out / update parts of the logic. Also, funds are kept at arm's length from functionality.

There is to be no constantly-updating oracle or gas-costly block-wise auctions for token holders.
