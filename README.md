# marginswap-core
Core contracts for marginswap functionality

## Install

Install dependencies:
```(shell)
yarn install
```

Place a private key file in your home folder `~/.marginswap-secret`. If you want it to match up with your wallet like MetaMask, create the account in your wallet, copy the private key and paste it into the file.


## Disclaimer

This is work in progress, it isn't completely tested. It will have bugs. Do not let this touch real money. It is a prototype of functionality.

## Rationale

We have gone for a relatively modular approach which should make it easy for governance to switch out / update parts of the logic. Also, funds are kept at arm's length from functionality.

There is to be no constantly-updating oracle or gas-costly block-wise auctions for token holders.
