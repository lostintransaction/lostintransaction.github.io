    Title: Computing a Bitcoin Address, Part 4: Wallet Import Format (WIF)
    Date: 2014-04-09T03:02:03
    Tags: private key, Bitcoin addresses, MultiBit, Bitcoin wallets, Racket

In previous posts, we figured out how to compute a Bitcoin address
from a private key and we tested our code with an
[example from the Bitcoin wiki][bwiki:addr]. In this post we try to
convert a private key from a real wallet (MultiBit) to its
corresponding address.

[bwiki:addr]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin wiki: Bitcoin addresses"

<!-- more -->

> This is the fourth post in a four-part series titled "Computing a Bitcoin Address".
> Here are all the articles in the series:
>
> * Part 1: [Private to Public Key](http://www.lostintransaction.com/blog/2014/03/14/computing-a-bitcoin-address-part-1-private-to-public-key/)
> * Part 2: [Public Key to (Hex) Address](http://www.lostintransaction.com/blog/2014/03/15/computing-a-bitcoin-address-part-2-public-key-to-hex-address/)
> * Part 3: [Base58Check Encoding](http://www.lostintransaction.com/blog/2014/03/18/computing-a-bitcoin-address-part-3-base58check-encoding/)
> * Part 4: [Wallet Import Format (WIF)](http://www.lostintransaction.com/blog/2014/04/09/computing-a-bitcoin-address-part-4-wallet-import-format-wif/) (this post)

### From Private Key to Public Address

Let's consolidate the code from the previous posts to create one
function that performs all the steps to convert a private key to a
public address. First we create some helper functions:

```racket
(define (hash160/hex hstr) (ripemd160/hex (sha256/hex hstr)))
(define (sha256x2/hex hstr) (sha256/hex (sha256/hex hstr)))
(define (add-version0 str) (string-append "00" str))
;; checksum is 1st 4 bytes (8 chars) of double sha256 hash of given hex string
(define (get-checksum hstr) (substring hstr 0 8))
(define (compute-checksum hstr) (get-checksum (sha256x2/hex hstr)))
(define (add-checksum hstr) (string-append hstr (compute-checksum hstr)))
```

* `hash160/hex`: performs a SHA-256 hash followed by a RIPEMD-160 hash
on an input hex string
* `sha256x2/hex`: performs SHA-256 twice on an input hex string
* `add-version0`: prepends `0x00` to a hex string
* `compute-checksum`: computes checksum (first 4 bytes of a double SHA-245 hash) of its input
* `add-checksum`: computes a checksum for its input and appends that checksum to the end of the input

Here's a function `priv-key->addr` that converts a private key (in hex) to a public address (in Base58Check):

```racket
;; computes base58 addr from hex priv key
(define priv-key->addr
  (compose hex-str->base58-str
           add-checksum
           add-version0
           hash160/hex
           priv-key->pub-key))
```

We use Racket's `compose` function, which strings together a series of
functions. The functions are called in the reverse order in which they
are listed, so `priv-key->addr` first calls `priv-key->pub-key` on its
input, then takes that results and give it to `hash160/hex`, and so
on. 

Let's test this function on [the Bitcoin wiki example][bwiki:addr]:

* private key: `18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725`
* public address: `16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM`

We save the code to the file `priv2addr.rkt`:

    $ racket
    Welcome to Racket v6.0.0.3.
	-> (require "priv2addr.rkt")
	-> (define priv-key "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725")
	-> (priv-key->addr priv-key)
	"16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

### A MultiBit Wallet

Now let's test our function on a real private key. I created a new
wallet in MultiBit and it generated address
`1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j`. I then exported the private key
associated with this address into a file. Here's the contents of that
file:

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

Let's see if we can convert this private key
(`L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe`) to its public
address (`1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j`). The key is in base-58
so we need convert to hex first.

	$ racket
	Welcome to Racket v6.0.0.3.
	-> (require "priv2addr.rkt" "base58.rkt")
	-> (define priv/base58 "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe")
	-> (define priv/hex (base58-str->hex-str priv/base58))
	-> (priv-key->addr priv/hex)
	"1GoZxLR83RfoZeqzNSdTZuEb4vHAc6zFfc"
	
Hmm, we get the wrong address! Querying the private key at
[bitaddress.org](http://bitaddress.org) reveals that the private key
is

1. in [Wallet Import Format (WIF)][bwiki:wif], and
2. in compressed form.

[bwiki:wif]: https://en.bitcoin.it/wiki/Wallet_import_format "Wallet import format"

Here's the relevant details of Wallet Import Format:

Uncompressed WIF private key:

    0x80 + 32 byte raw private key + 4 byte checksum
	
Compressed WIF private key:

    0x80 + 32 byte raw private key + 0x01 + 4 byte checksum
	
The `0x80` prefix indicates an address on the main Bitcoin blockchain
(as opposed to the testnet). The compressed form has an extra `0x01`
byte before the checksum.

### WIF Checksum Checking

Before converting the WIF private key to an address, let's first write
a function that checks the checksum for a WIF private key. We need to first determine if a WIF private key is compressed:

```racket
;; wif is in base58
(define (wif-compressed? wif)
  (define len (string-length wif))
    (when (not (or (= len 51) (= len 52)))
      (error 'wif-compressed? "invalid WIF: ~a\n" wif))
  (define c (string-ref wif 0))
  (or (char=? c #\K) (char=? c #\L)))
```
			
A compressed WIF private key begins with a `K` or `L` and
`wif-compressed?` checks for this.

Next we define a prediate that verifies a WIF private key's checksum. The checksum is again computed with a double SHA-256.

```racket
;; splits wif into prefix + checksum
;; wif is in base58 but results are in  hex
(define (wif-split-checksum wif)
  (define wif/hex (base58-str->hex-str wif))
  (cond [(wif-compressed? wif)
         (values (substring wif/hex 0 68) (substring wif/hex 68 76))]
        [else
         (values (substring wif/hex 0 66) (substring wif/hex 66 74))]))

(define (hex=? str1 str2) (string=? (string-upcase str1) (string-upcase str2)))

;; wif is in base58
(define (wif-checksum-ok? wif)
  (define-values (wif-prefix wif-checksum) (wif-split-checksum wif))
  (hex=? wif-checksum (compute-checksum wif-prefix)))
```

First, `wif-split-checksum` splits a WIF private key into a prefix and
a checksum. Then, `wif-checksum-ok?` computes a double SHA-256 on the
prefix and verifies that it matches the checksum.

Let's try these functions on our example:

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (define wif/comp "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe")
	-> (wif-checksum-ok? wif/comp)
	#t
	
We can also try on the uncompressed WIF private key, which according
to [bitaddress.org](https://www.bitaddress.org), is
`5KDwznXNT8sJbhtYheFNB1ho9Yb69hfJGgmTkW9cNVBr7LxFEje`.

    -> (define wif/uncomp "5KDwznXNT8sJbhtYheFNB1ho9Yb69hfJGgmTkW9cNVBr7LxFEje")
	-> (wif-checksum-ok? wif/uncomp)
	#t
	
### From WIF Private Key to Address

To convert from a WIF private key to an address, we need to:

1. decide whether the WIF private key is compressed,
2. extract the raw private key, and
3. compute either an uncompressed or compressed Bitcoin address.

We have already defined code for step 1. For step 2, we just drop all
prefixes and checksums from the WIF private key:

```racket
;; wif is in base58, priv key is in hex
(define (wif->priv-key wif) (substring (base58-str->hex-str wif) 2 66))
```

To verify, let's check the hash160 of our running example, which [blockchain.info reports to be][blockchain] `a62bc20c511af7160a6150a72042b3fff8a86646`:

[blockchain]: https://blockchain.info/address/1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j "blockchain.info 1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "priv2addr.rkt" "priv2pub.rkt")
	-> (define wif "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe")
	-> (wif->priv-key wif)
	"B96CA0C6390D4734C80A44ECD4ACEF21E2886BA250EC1D8CF461F1C94FAE6EA9"
	-> (priv-key->pub-key/compressed ^)
	"036eef34887c91e2ed2815de2192bd541867708bb1c7434cd571073ddecaaafc42"
	-> (hash160/hex ^)
	"a62bc20c511af7160a6150a72042b3fff8a86646"

For step 3, we first need a compressed version of our `priv-key->addr`
function. This requires getting a compressed public key, but
fortunately we've already defined a `priv-key->pub-key/compressed` in
a [previous post][LiT:priv2pub]. Here's `priv-key->addr/compressed`:

[LiT:priv2pub]: http://www.lostintransaction.com/blog/2014/03/14/computing-a-bitcoin-address-part-1-private-to-public-key/ "Computing a Bitcoin Address, Part 1: Private to Public Key"

```racket
;; computes base58 addr from compressed (hex) priv key
(define priv-key->addr/compressed
  (compose hex-str->base58-str
           add-checksum
           add-version0
           hash160/hex
           priv-key->pub-key/compressed))
```

Finally, we can define `wif->addr`, which converts a WIF private key
to a Bitcoin address:

```racket
;; wif and addr are base58
(define (wif->addr wif)
  (define priv (wif->priv-key wif))
  (if (wif-compressed? wif)
      (priv-key->addr/compressed priv)
      (priv-key->addr priv)))
```

Here's our example, with the expected representations (from [bitaddress.org](https://www.bitaddress.org)):

* WIF private key, compressed: `L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe`
* public address, compressed: `1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j`
* WIF private key, uncompressed: `5KDwznXNT8sJbhtYheFNB1ho9Yb69hfJGgmTkW9cNVBr7LxFEje`
* public address, uncompressed: `15YzfXwEg5STm3GtEh87LAyzNbpVpdx5eN`

Let's test that our code gives the expected results:

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "priv2addr.rkt")
	-> (define wif/comp "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe")
	-> (wif->addr wif/comp)
	"1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j"
	-> (define wif/uncomp "5KDwznXNT8sJbhtYheFNB1ho9Yb69hfJGgmTkW9cNVBr7LxFEje")
	-> (wif->addr wif/uncomp)
	"15YzfXwEg5STm3GtEh87LAyzNbpVpdx5eN"
	
### Software

All the code from this post
[is available here](http://www.lostintransaction.com/code/priv2addr.rkt).
In this post, I'm using Racket 6.0.0.3, running in Debian 7.0.
