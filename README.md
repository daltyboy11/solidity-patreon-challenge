# A basic Patreon clone in Solidity

This is a toy project to teach important Solidity and Hardhat concepts.

## Challenge
There are two interfaces, `IPatreon.sol` and `IPatreonRegistry.sol` with full [NatSpec](https://docs.soliditylang.org/en/v0.8.13/natspec-format.html) descriptions. Your goal is to implement them in `Patreon.sol` and `PatreonRegistry.sol` and pass the unit tests in `patreon-test.js` and `patreon-registry-test.js`.

### Challenge setup
#### **Clone and run the project**
Verify you can get the project up and running with the following (you must have npm installed):
```
git clone git@github.com:daltyboy11/solidity-patreon-challenge.git
npm install
npx hardhat test
```

#### **Checkout the `interfaces-only` branch**
```
git checkout interfaces-only
```
This branch has the skeleton implementations you need to implement. Start on this branch to implement your solution.

#### Start coding!
Your task is to convert the NatSpec description to a working implementation.
Your solution is finished when you pass all the test cases
```
npx hardhat test
```
Give it your best shot! Remember to use the hints and other external solidity resources. You can also look at my solution on the `main` branch.

### Hints
Remember there is no "right" solution because there are many possible implementations. Here are some topics that will help you along the way:
- [Mappings](https://solidity-by-example.org/mapping/)
- [Modifiers](https://solidity-by-example.org/function-modifier/)
- The difference between `memory` and `storage`
- [NatSpec](https://docs.soliditylang.org/en/develop/natspec-format.html)
- Solidity [style guide](https://docs.soliditylang.org/en/v0.8.13/style-guide.html)
- Solidity [security considerations](https://docs.soliditylang.org/en/v0.8.13/security-considerations.html)

### Feedback
Want to make a suggestion for improvement? Open up an issue or a pull request :).