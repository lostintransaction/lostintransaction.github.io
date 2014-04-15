    Title: Computing a Bitcoin Address, Part 4: Wallet Import Format (WIF)
    Date: 2014-04-09T03:02:03
    Tags: private key, Bitcoin addresses, MultiBit, Bitcoin wallets, Racket

In previous posts, we figured out how to compute a Bitcoin address
from a private key, using an example from the Bitcoin wiki. In this
post we try to convert a private key generated from an actual
(MultiBit) wallet to an address.

<!-- more -->
    
I created a new wallet in MultiBit and it generated address
`1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j`. I then exported the private key
associated with this address into a file. Here's the contents of that file:

    # KEEP YOUR PRIVATE KEYS SAFE !
    # Anyone who can read this file can spend your bitcoin.
	#
	# Format:
	#   <Base58 encoded private key>[<whitespace>[<key createdAt>]]
	#
	#   The Base58 encoded private keys are the same format as
	#   produced by the Satoshi client/ sipa dumpprivkey utility.
	#
	#   Key createdAt is in UTC format as specified by ISO 8601
	#   e.g: 2011-12-31T16:42:00Z . The century, 'T' and 'Z' are mandatory
	#
	L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe` 2014-03-10T06:12:28Z
	# End of private keys

Let's see if the program we wrote in the last series of posts can
compute the address (`1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j`) from the
private key
(`L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe`). The key is
in base58 so we need convert to hex first.

	$ racket
	Welcome to Racket v6.0.0.3.
	-> (require "priv2addr.rkt" "base58.rkt")
	-> (define priv/hex (base58-str->hex-str "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe"))
	-> (priv-key->addr priv/hex)
	"1GoZxLR83RfoZeqzNSdTZuEb4vHAc6zFfc"
	
Hmm, we get the wrong address.
	
