# ValidatorContract
This project implements a Validator Reward System . It allows users to lock their ERC721 licenses, receive rewards in ERC20 tokens over time, and unlock their licenses after a specified period (epoch). Rewards decrease with each epoch. Epoch 0 starts when contract is deployed and then epoch changes every N blocks. Every epoch reward amount decreases fixed amount (rewardDecreaseRate) eventually becoming equal to 0. In order to save gas contract only works with tokenIds in range of uint192.


## Contracts Overview
- RewardToken: An ERC20 token that serves as the reward currency for validators
- License: An ERC721 token that represents licenses required for participating as a validator.
- ValidatorContract: manages the core functionality of the validator reward system, allowing users to lock their licenses, claim rewards, and unlock their licenses.

### Key Functions of ValidatorContract:
- lockLicense(uint256 tokenId): Allows users to lock their license and begin earning rewards.
- unlockLicense(uint256 tokenId): Allows users to unlock their license after one full epoch and claim any accumulated rewards.
- claimRewards(): Allows users to claim rewards for all licenses they have locked.


## Setup Instructions

### Prerequisites
- Foundry installed
### Install Dependencies
To install the necessary packages, run:

```bash
forge install
```
### Compile Contracts
To compile the smart contracts, execute:
```bash
forge build
```

### Run Tests
To run the tests, use:
```bash
forge test -vv
```

### Deploy Contracts
To deploy the contracts to sepolia (.env need to be set)
```bash
forge script --chain sepolia script/ValidatorContract.s.sol:ValidatorContractScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
```
.env example:
```json
SEPOLIA_RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
OWNER=
```
### View Test Coverage
To see the test coverage report, run:
```bash
forge coverage
```

## Deployments on sepolia
1. [License](https://sepolia.etherscan.io/address/0xac85efeec9fef1c8cb79f08e63d1d80d1307eb8f) - License ERC721 
2. [RewardToken](https://sepolia.etherscan.io/address/0x623fc8c6d1f68659e3ec16beac42c7f75a88c1e7) - erc-20 reward token contract
3. [ValidatorContract](https://sepolia.etherscan.io/address/0x5c9fb48b674da5eef2dccdc2f17299ff9b2c7184) - ValidatorContract, the main contract to interact with

## Possible improvements
- make contracts upgreadeable 
- default approver for ERC721
  - so users won't need to approve NFTS to the main contract
- function lock() and unlock() can take arrays of ids, making it easier to work with more tokens
- also, if we make function claimReward() to work with specific tokenId or array of ids then we don't need to store array of all the tokens for the user, hus saving gas on storage.
- testing more test cases
