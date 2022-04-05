# A basic Patreon clone in Solidity

This is a toy project meant to teach important Solidity and Hardhat concepts.

## Challenge
There are two interfaces, `IPatreon.sol` and `IPatreonRegistry.sol` with full [NatSpec](https://docs.soliditylang.org/en/v0.8.13/natspec-format.html) descriptions. Your goal is to implement them in `Patreon.sol` and `PatreonRegistry.sol` and pass the unit tests in `patreon-registry-test.js` and `patreon-test.js`.

At the end of this challenge you will have learned important concepts in Solidity, the [ethers library](https://docs.ethers.io/v5/), and testing with hardhat.

### Challenge setup
#### **Clone and run the project**
Verify you can get the project up and running with the following (you must have npm installed)
```
git@github.com:daltyboy11/solidity-patreon-challenge.git
npm install
npx hardhat test
```
#### **Checkout the `interfaces-only` branch**
```
git checkout interfaces-only
```
This branch is missing the implementations. The skeletons are provided but each function just `revert`s. Start on this branch to implement your solution.

### Hints
Remember there is no "right" solution because there are many possible implementations. Here are some Solidity topics that will help you along the way: