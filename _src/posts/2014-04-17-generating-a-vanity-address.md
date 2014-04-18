    Title: Generating a Vanity Address
    Date: 2014-04-17T03:43:06
    Tags: Bitcoin addresses, private key, WIF, MultiBit, Racket

It a [previous series of posts][LiT:addr], we figured out how to
derive a Bitcoin public address from a private key. What should we do
with this new knowledge? Let's generate a bunch of addresses!
Specifically, we'll create a "vanity" address generator.

[LiT:addr]: http://www.lostintransaction.com/blog/2014/03/14/computing-a-bitcoin-address-part-1-private-to-public-key/ "Computing a Bitcoin Address"

<!-- more -->

Most Bitcoin wallets generate addresses randomly.  A Bitcoin
[vanity address][bwiki:vanity], however, is one that has a prefix
specified by the user.  Of course, you don't want to trust a third
party to create a private key for you, so let's generate our
own. (Yes, I know that `vanitygen` is open source and has tons more
features but it's still more fun to roll our own!) As usual, I'll be
using [Racket](http://racket-lang.org).

[bwiki:vanity]: https://en.bitcoin.it/wiki/Vanitygen "Vanitygen"

First, we need to generate a random private key. Bitcoin private keys
are 32 bytes long.

```racket
(define (random-byte) (random 256))

;; generates raw 32 byte private key (in hex)
(define (random-priv-key)
  (bytes->hex-string (apply bytes (for/list ([i 32]) (random-byte)))))
```

> WARNING #1: Racket's `random` function is
  [seeded with the system time][docs:pseudo] and is thus not
  [completely random](https://cwe.mitre.org/data/definitions/337.html). When
  generating addresses for real-world usage, use a
  [cryptographically secure source of randomness][wiki:pseudo] like
  `/dev/random`.

[docs:pseudo]: http://docs.racket-lang.org/reference/generic-numbers.html?q=make-pseudo-random-generator#%28def._%28%28quote._~23~25kernel%29._make-pseudo-random-generator%29%29 "Racket docs: make-pseudo-random-generator"
[wiki:pseudo]: http://en.wikipedia.org/wiki/Cryptographically_secure_pseudorandom_number_generator "Wikipedia: Cryptographically secure pseudorandom number generator"

> WARNING #2:
  [Not every 32 byte number is a valid private key][bwiki:priv]. But
  here I assume that it's sufficiently unlikely that I'll randomly
  generate an invalid key, so I ignore this issue.

[bwiki:priv]: https://en.bitcoin.it/wiki/Private_key#Range_of_valid_private_keys "Range of valid private keys"

Once we have a private key, we need to convert to
[wallet import format (WIF)][bwiki:wif]. To do this we need to decide
if we want a compressed or uncompressed address. These days most
addresses in use are compressed so we'll go with compressed. The
format for a compressed WIF private key is:

    0x80 + 32 byte raw private key + 0x10 + 4 byte checksum
   
To create a WIF private key we append `0x80` to the front of our
randomly generated raw private key to indicate "mainnet" (as opposed to
"testnet") and we append `0x01` to the end to indicate compression. We
then compute a checksum for this string and append that to the end of
the string. A checksum is the first 4 bytes of a double SHA-256 hash,
as we [saw previously][LiT:wif].

[bwiki:wif]: https://en.bitcoin.it/wiki/WIF "Wallet import format"
[LiT:wif]: http://www.lostintransaction.com/blog/2014/04/09/computing-a-bitcoin-address-part-4-wallet-import-format-wif/ "Computing a Bitcoin Address, Part 4: Wallet Import Format (WIF)"

Here's a Racket function `priv-key->wif/compressed` to convert a raw
private key to wallet import format. We use `add-checksum` from
[a previous post][LiT:wif].

```racket
(define (add-mainnet80 str) (string-append "80" str))
(define (add-compression-flag str) (string-append str "01"))
;; converts raw priv key (in hex) to wif (in base58)
(define (priv-key->wif/compressed priv)
  (hex-str->base58-str (add-checksum (add-compression-flag (add-mainnet80 priv)))))
```

To generate a random address, we use the functions defined in this
post, and `wif->addr` [from a previous post][LiT:wif], which converts
a WIF private key to an address. To get a vanity address, we check if
the prefix of the generated address matches a specified substring (all
Bitcoin addresses start with '1', so prefix here means the substring
after the '1').

The following Racket function `get-vanity-addr` repeatedly generates a
random private key, converts it to an address, and checks if the
prefix of the address matches the input "vanity" substring. If no
matching address is found after the specified number of `tries`
(default is 1,000,000 tries), the function gives up. Otherwise, the
function returns the raw private key, the WIF private key, and the
public address.

```racket
(define (get-vanity-addr prefix #:tries [tries 1000000])
  (define prefix1 (string-append "1" prefix))
  (define prefix-len (string-length prefix1))
  (let loop ([n tries])
    (if (zero? n)
    (printf "\nCouldn't find matching address in ~a tries\n" tries)
    (let* ([priv (random-priv-key)]
           [priv/wif (priv-key->wif/compressed priv)]
           [addr (wif->addr priv/wif)])
      (if (string=? (substring addr 0 prefix-len) prefix1)
          (values priv priv/wif addr)
          (loop (sub1 n)))))))
```

Let's try it. I specify a prefix of "11", so the function tries to
find an address with three leading '1's:

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "vanity.rkt")
	-> (get-vanity-addr "11")
	Address found! -----------------------------------------------
	private key: 286a5cdfb346648b902fe30c46e2f44246d9071ab5ddcf2fb6101a657cbc18de
	private key (WIF): KxaGocHndfhXzPGdrDTfr6EDvnNfbdZwdxcX7xtjL6UnERFZhtkZ
	public address: 111ksvuJkfkFef8krFpsUeKDrCSedKpxM
	
We found an address! To check that it's a valid address, I sent some
BTC to the address to confirm. Lo and behold,
[the transactions appear in the blockchain][blockchain]!

[blockchain]: https://blockchain.info/address/111ksvuJkfkFef8krFpsUeKDrCSedKpxM "blockchain.info"

Next I imported the WIF private key into MultiBit. MultiBit requires
that the key be accompanied by a time in UTC format and saved to a
file so here's the contents of the file I created and imported into
MultiBit:

    KxaGocHndfhXzPGdrDTfr6EDvnNfbdZwdxcX7xtjL6UnERFZhtkZ 2014-04-15T06:12:28Z

To make sure the import succeeded, I spent the BTC that I just
received. [Checking the blockchain again][blockchain], we can see that
sending BTC from our generated address worked as well!

### Software

All the code from this post
[is available here](http://www.lostintransaction.com/code/vanity.rkt).
In this post, I'm using Racket 6.0.0.3 running in Debian 7.0, and
MultiBit 0.5.17 running in Windows 7 64-bit.
