# Scope

- OptimismPortal's withdrawEthBalance function: contracts/L1/OptimismPortal.sol:504
- L1StandardBridge's  withdrawErc20Balance function: contracts/L1/L1StandardBridge.sol:272
- BalanceClaimer contract: contracts/L1/winddown/BalanceClaimer.sol

# Properties

| Id  | Properties                                                                          | Type             |
| --- | ---------------------------------------------------                                 | ------------     |
| 1   | a valid claim should be redeemable once                                             | State transition |
| 2   | a valid claim should not be redeemable more than once                               | State transition |
| 3   | a claim should be set as claimed when claimed                                       | State transition |
| 4   | an invalid claim should not be redeemable                                           | State transition |
| 5   | for each token, token.balanceOf(L1StandardBridge) == initialBalance - sum of claims | High-level       |
| 6   | OptimismPortal.balance == initialBalance - sum of claims                            | High-level       |


# testing methodology
The fact that the state root is not writeable in the lifetime of the contract is cool from a design standpoint, but that also means the root has to be generated, and the valid claims chosen, before it makes sense to call any other handler. Doing so in the constructor is not viable, since it's only ever called once for the entire fuzzing campaign and doesnt get any fuzz input, the alternatives I could think of are the following:

## mutate the state root
Idea for this is to initialize the BalanceClaimer in the campaign constructor with either

- [ ] an empty state root (for ...purity? ie allowing the fuzzer choose the inputs with the greatest variability)
- [ ] pre-filled state root (to cover code faster) and set of valid claims, with the downside of calls creating

and have handlers to _add_ valid claims to the set, overwriting the state root

This has the downside of being dissimilar to the actual production usage in a very crucial way, but also the invariant we would be breaking  (the state root not changing) can be easily enforced by the compiler (ie: make the field immutable), and the upside of exploring a lot of possible trees in a simpler way

## use a modifier to ensure the first call of the sequence initializes a state root

this would involve
- [ ] not creating the balanceClaimer in the constructor
- [ ] have a modifier (and an extra param of fuzzed input in every handler/property check) which will be used to initialize the state root on the first call
- [ ] have all handlers afterwards only process claims (valid or not, obviously) and not create new ones

This has the upside of being identical to the production setup, but would yield uglier code and potentially have worse pseudorandom input since we would be having all the state as fields of structs in arrays

# nice to haves
- [ ] use tokens' actual bytecode in the fuzzing campaign

