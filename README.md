# marginswap-core
Core contracts for marginswap functionality

## Install

Install dependencies:
```(shell)
yarn install
git clone git@github.com:marginswap/core-abi.git build
```

Place a private key file in your home folder `~/.marginswap-secret`. If you want it to match up with your wallet like MetaMask, create the account in your wallet, copy the private key and paste it into the file.

## Rationale

`MarginRouter` is the entry point for most traders to interact with the protocol. `Lending` and `CrossMarginTrading`, as well as their ancilliary superclasses are the lending and borrowing sides of the system.

We have gone for a relatively modular approach which should make it easy for governance to switch out / update parts of the logic. There is a central registry for roles. Also, funds are kept at arm's length from functionality.

The `DependencyController` contract provides cache invalidation and tracking of roles and relationships between contracts, central verification of integrity of our ownership structure as well as additonal safeguards for governance-approved protocol-wide actions.

There is to be no constantly-updating oracle or gas-costly block-wise auctions for token holders.
