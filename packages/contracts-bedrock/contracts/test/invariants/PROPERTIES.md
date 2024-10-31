# Scope

- OptimismPortal's withdrawEthBalance function: contracts/L1/OptimismPortal.sol:504
- L1StandardBridge's  withdrawErc20Balance function: contracts/L1/L1StandardBridge.sol:272
- BalanceClaimer contract: contracts/L1/winddown/BalanceClaimer.sol

# Properties

| Id  | Properties                                                                          | Type             | Checked |
| --- | ---------------------------------------------------                                 | ------------     | ---     |
| 1   | a valid claim should be redeemable once                                             | State transition | [x]     |
| 2   | a valid claim should not be redeemable more than once                               | State transition | [x]     |
| 3   | a user should be set as claimed when they process a claim                           | State transition | [x]     |
| 4   | an invalid claim should not be redeemable                                           | State transition | [x]     |
| 5   | for each token, token.balanceOf(L1StandardBridge) == initialBalance - sum of claims | High-level       | [x]     |
| 6   | OptimismPortal.balance == initialBalance - sum of claims                            | High-level       | [x]     |


## testing methodology
The fact that the state root is not writeable in the lifetime of the contract is cool from a design standpoint, but that also means the root has to be generated, and the valid claims chosen, before it makes sense to call any other handler.

As a first approach, we've meta-programmed a solidity source file with a hard-coded set of valid claims, which can be refreshed by calling  `./generate-random-tree.sh`.
This is not ideal, as all fuzzing runs are going to run on the same merkle tree instead of letting the fuzzer explore new ones. Some alternatives are described below:

### mutate the state root
Idea for this is to initialize the BalanceClaimer in the campaign constructor with either

- [ ] an empty state root (for ...purity? ie allowing the fuzzer choose the inputs with the greatest variability)
- [ ] pre-filled state root (to cover code faster) and set of valid claims, with the downside of calls creating

and have handlers to _add_ valid claims to the set, overwriting the state root

This has the downside of being dissimilar to the actual production usage in a very crucial way, but also the invariant we would be breaking  (the state root not changing) can be easily enforced by the compiler (ie: make the field immutable), and the upside of exploring a lot of possible trees in a simpler way

### use a modifier to ensure the first call of the sequence initializes a state root
this would involve
- [ ] not creating the balanceClaimer in the constructor
- [ ] have a modifier (and an extra param of fuzzed input in every handler/property check) which will be used to initialize the state root on the first call
- [ ] have all handlers afterwards only process claims (valid or not, obviously) and not create new ones

This has the upside of being identical to the production setup, but would yield uglier code and potentially have worse pseudorandom input since we would be having all the state as fields of structs in arrays

# nice to haves
- [ ] use tokens' actual bytecode in the fuzzing campaign
- [ ] use a full uint256 for the range of the amounts in merkle tree
    - [ ] use bigger number in script
    - [ ] handle fails caused by insufficient balances
- [ ] create a larger share of claims with incomplete list of tokens or zero eth
- [ ] handlers for withdraw{Erc20,Eth}Balance methods
    - [ ] guided
    - [ ] unguided

