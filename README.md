# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder

## versions: 

The following tools and versions were used in the project

| package | Version |
|:-------:|:-------:|
| nodejs | 10.12.0 |
| npm | 6.4.1 |
| Truffle | 5.1.64 |
| Solidity | 0.4.24 |
| web3.js | 1.3.3 |
| Ganache | 2.5.4 |

## Tests:

### flight Surety

`truffle test ./test/flightSurety.js`
![](imgs/tests.png)

### Orcale tests

`truffle test ./test/oracles.js`
![](imgs/oracletests1.png)
![](imgs/oracletests2.png)

### Oracle Registrations

`npm run server`
![](imgs/orcaleRegistration.png)

### flight registration

![](imgs/flightRegisration.png)

### Purchase Insurance

![](imgs/purchaseInsurance.png)

### Insurance Purchased

![](imgs/insurancePurchased.png)

### Withdraw Insurance

![](imgs/insurancePayout.png)

## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)