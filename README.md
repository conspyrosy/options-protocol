# options-protocol

A naive (unfinished) implementation of an options protocol. Allows exercise of ETH put options in arbitrary strike assets up until a certain expiry date.

## Brief

An option gives the holder the right but not the obligation to sell their ETH for $100 anytime before
April 20th 2021.
You have been given such an option. It is September 20th 2020 and the price of ETH crashes to $50.

That means, you get to exercise your option and make some profits.

The issue is however, the option protocol, does not know who to take money from. It is your job to help
the protocol which has multiple option sellers
and multiple option buyers figure out how to design an exercise function.

BEFORE:

Option Holder Balance:
	10 options - to sell at 100
  10 ETH
  0  USDC


AFTER EXERCISE:

Option Holder Balance:
	0 options
  0 ETH
  1000 USDC
  
## Approach

An option exists with the following features (strikeCurrency, strikePrice, expiryDate).
- Anyone with option tokens can exchange them at any point until expiry for {optionsHeld * strikePrice} strikeCurrency.
- Anyone can mint an option so long as the option has not expired. The pool keeps track of minters and the amount they have minted so that once the expiry date has passed, minters can claim their share of the pool. Any unexercised option tokens will be worthless at that point, and thus can not impact the pool holdings.
- Minters can reclaim their collateral post-expiry. It uses the persistent in-contract accounting to determine how much of the pool a minter is entitled to. Once their share is claimed, they are entitled to 0, and the accounting is updated.

To perform the actions above we expose 3 methods:
- mintOption(optionsToCreate) - mint options by providing full collateral required for the buyer to exercise if they wish. collateral required will need to be approved for the contract to spend.
- exerciseOption(tokensToExercise) - exercise options by providing the ETH and option tokens in exchange for performing the exchange.
- reclaimCollateral() - reclaim collateral post-expiry. this will return a combination of ETH and strikeCurrency depending on if (and how many) options have been exercised.

There are also some getters which can be exposed to a UI which tell us information about option counts:
- totalActiveOptions is the total amount of options minted minus any tokens minted that collateral has been reclaimed for. if the option is still active, this is the total amount of minted options as no collateral can be claimed by minters until after expiry.
- getUsersActiveOptions is the amount of options a user has minted. if they have reclaimed the collateral on their options (post-strike), this value becomes 0.

There is no factory, but in reality there would be one which could construct options with different (strikeCurrency, strikePrice, expiryDate) combinations if they dont exist. if that combination does exist it would return the address for the existing token.