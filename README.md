# SimpleDAO

A simple DAO written in [Fe](https://fe-lang.org/), using [Foundry](https://getfoundry.sh/) for tests and more.

<img src="https://raw.githubusercontent.com/ethereum/fe/master/logo/fe_svg/fe_source.svg" width="150px">

<br>

# What is this

This is heavily inspired by the original [Gnosis Multisig Wallet](https://github.com/OpenZeppelin/gnosis-multisig/blob/master/contracts/MultiSigWallet.sol) but deviates from a simple multisig wallet in a few ways. A traditional multisig wallet requires a minimum number of signers to sign a transaction before it gets executed (e.g. 2 of 3).

Tranditional DAOs usually require a quorum of votes from all governance token holders to execute a transaction. These voting schemes come at a cost of complexity. While there are very well [established solutions written in Solidity](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes) there are no such solutions written in Fe yet.

This project aims to provide a very simple DAO implementation that blends the concepts of traditional multisigs and coin voting DAOs.


# How it works

Just like in a traditional multisig wallet, the DAO holds a set of members that can be added and removed. Each member has a weight that is derived from the amount of governance tokens they hold. The weight is used to determine the voting power of each member. The DAO has a configurable quorum expressed as a percentage that is required to reach before a transaction will be executed. The quorum is calculated based on the total weight of all members and the weight of all members that confirmed a transaction. For example, if the quorum is set to 50% and the DAO has 2 members Alice and Bob and Alice holds 4 governance tokens and Bob holds 6 governance tokens, then Bob will be able to execute transactions without Alice's confirmation but Alice will need Bob's confirmation to execute transactions.

In established DAO schemes, snapshot mechanisms are used to prevent double voting. A snapshot mechanism ensures that a user can not vote on an execution, then transfers their tokens to another account to vote again with essentially the same tokens, hence double voting.

This DAO uses a very simple implicit snapshot mechanism to safeguard against double voting. Note that this also comes at a cost which mainly means that the scheme is very opionated and less flexible than other DAO schemes.

1. Upon creation of the governance token, the entire supply is minted to the DAO and no further minting is possible.

2. The DAO is the only account that is in control of the governance tokens and can transfer them to other accounts.

3. Upon initialization of the DAO a list of founding members and there token allocation is provided. The DAO will then transfer the tokens to the founding members and internally tracks the allocation of tokens per member as well as the total amount of tokens distributed to all members. This can be seen as a snapshot and it is important to understand that these numbers won't change even if members transfer their tokens to other accounts. The DAO can also transfer tokens to accounts that are not members of the DAO and these tokens will not be tracked by the DAO.

4. The DAO can call the `add_owner(mut self, mut ctx: Context, owner: address, distribute_amount: u256)` function to add a new member to the DAO. The DAO will transfer the specified amount of tokens to the new member (which can be `0`) and update its internal snapshot of the token allocation.

5. Similarly, `remover_owner` and `replace_owner` can be used to alter the set of members and the internal snapshot.

6. The DAO can call `update_weights` to update its internal snapshot of weights explicitly. This is useful if members transferred tokens to other accounts and the DAO wants to update its snapshot.



## Caveats

1. Holding governance tokens does not *automatically* grant voting rights. The DAO needs to explicitly add members and if they decide to not add someone, they can't vote even if they hold tokens.


# Prerequisite
# Installation / Setup

To set up Foundry x Fe, first make sure you have [Fe](https://fe-lang.org/) installed. Further make sure to set the `FE_PATH` environment variable to the path of the `fe` executable.

Then follow the [Foundry installation guide](https://book.getfoundry.sh/getting-started/installation) to install Foundry.

Set up an environment variable `MAINNET_JSON_RPC` to point to a mainnet node. For example, you can use [Alchemy](https://alchemyapi.io/) or [Infura](https://infura.io/).

# Run the tests

## Foundry tests using solidity

We fork from mainnet to pull some DAI and other things into our test environment.

Run `forge test --fork-url $MAINNET_JSON_RPC`

## Fe tests

Run `$FE_PATH test fe_contracts/simpledao/`

## Deployment

Scripts exist in the `scripts` folder to assist with the deployment. The scripts are written in a way to work with
local, test or production networks and can hence be used with different kind of wallet options (e.g. private key, mnemonic, hardware wallet, etc.).

1. Run `deploy.sh` with the instructions at the head of the file to deploy the DAO contract and the governance token.

2. Run `init.sol` with the instructions at the head of the file to initialize the DAO with a set of founding members and their token allocation.

## Usage

This project does not provide a frontend and best practices for interacting with the DAO are still being explored. One main concern when interacting with the DAO is to ensure that team members have a practical way to review what a proposed transaction does before they confirm it.

If a transaction is very simple, then we can use the dry run option of the `submit` script to compute the transaction data and a hash of it and compare that to the proposed transaction.

As an example, [this transaction](https://etherscan.io/tx/0x53b8b5a3153afd7c7c17a815337e6c37a1d92347476a7ef15be27e67890a128b) called `deposit()` on the rocket pool deposit contract with a value of `100000000000000000` WEI (`0.1` ETH).

We can copy the transaction data from the etherscan page and also compute the keccak hash using foundry:

```
cast keccak 0xd0368532000000000000000000000000dd3f50f8a6cafbe9b31a427582963f465e745af8000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000400d0e30db0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0x8d330ee7c12977e01248b4cc92371fa49cd83a842d8bbbbe8fa81c46191b0306
```

Now, if we assume this as a proposed tx that we would like to verify, that it in fact only calls `deposit()` on the rocket pool deposit contract with a value of `0.1` ETH, we would go as follows:

1. We call `cast calldata "deposit()"` to obtain the embedded calldata of the proposed tx. This would also work for more complex transactions with arguments.

2. Then we run `DRY=true TO=0xdd3f50f8a6cafbe9b31a427582963f465e745af8 WEI=100000000000000000 DATA=0xd0e30db0 forge script script/submit.sol`

Not that `TO` is set to the address of the rocket pool contract and `WEI` is set to the value of the proposed tx. The `DATA` is set to the calldata that we aquired in step 1.

The output of the script should look like this:

```
Dry run, not submitting transaction
  Transaction bytes:
  0xd0368532000000000000000000000000dd3f50f8a6cafbe9b31a427582963f465e745af8000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000400d0e30db0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
  keccak(transaction bytes):
  0x8d330ee7c12977e01248b4cc92371fa49cd83a842d8bbbbe8fa81c46191b0306
```

As we can see, the keccak hash of the transaction bytes matches the keccak hash of the proposed transaction. This means that the proposed transaction is indeed calling `deposit()` on the rocket pool deposit contract with a value of `0.1` ETH.

For more complex transactions a best practice may emerge that involves first writing a script that assembles the transaction and exposes a way to view the raw transaction bytes as well as the keccak hash of it. The script can then be committed to the repository and reviewed by all team members who can then use the script to verify the proposed transaction.
