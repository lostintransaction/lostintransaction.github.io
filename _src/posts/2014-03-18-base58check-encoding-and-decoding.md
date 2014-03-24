    Title: Base58Check Encoding and Decoding
    Date: 2014-03-18T05:44:11
    Tags: Base58Check, Racket, Bitcoin addresses

In previous posts, we looked at
[computing a Bitcoin public key from a private key][LiT:pubfrompriv],
and then [computing a Bitcoin address from a public key]. However, our
experiments dealt with hexadecimal representations of keys and
addresses, which is not the representation familiar to the public. In
practice, Bitcoin addresses use the more human-readable
[Base58Check][bwiki:b58] encoding, which we explore in this post.

[LiT:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/deriving-a-bitcoin-public-key-from-a-private-key/ "Deriving a Bitcoin Public Key From a Private Key"
[LiT:ffi]: http://www.lostintransaction.com/blog/2014/03/15/adding-openssl-bindings-to-racket-via-its-ffi/ "Adding OpenSSL bindings to Racket via its FFI"
[bwiki:b58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Base58Check encoding"

<!-- more -->

Here is the rationale for choosing Base58Check encoding, taken from
[comments in the Bitcoin reference implementation][bitcoinsrc]:

    // Why base-58 instead of standard base-64 encoding?
    // - Don't want 0OIl characters that look the same in some fonts and
    // could be used to create visually identical looking account numbers.
    // - A string with non-alphanumeric characters is not as easily accepted as an account number.
    // - E-mail usually won't line-break if there's no punctuation to break at.
    // - Double-clicking selects the whole number as one word if it's all alphanumeric.

[bitcoinsrc]: https://github.com/bitcoin/bitcoin/blob/f76c122e2eac8ef66f69d142231bd33c88a24c50/src/base58.h#L7-L12 "src/base58.h"

Basically, addresses should be easy for humans to read and
handle. Let's implement Base58Check encoding and decoding. Our code
will resemble the Bitcoin C++ code, but we will instead use
[Racket](http://racket-lang.org), so we can avoid the hassle of
`BIGNUM`s.

### Encoding ###

To convert from hexadecimal to Base58Check, we repeat `modulo 58` and
division operations on the hex string until we reach
zero. Unfortunately, Racket (or any other language I know) has no
built-in modulo and division operations for hex strings. It's much
easier to first convert to a base-10 number. Here's a Racket function
`hex-str->num` that converts from hex to base-10.

```racket
(define ASCII-ZERO (char->integer #\0))

;; converts a hex digit [0-9A-Fa-f] to a number from 0 to 15
(define (hex-char->num c)
  (if (char-numeric? c)
      (- (char->integer c) ASCII-ZERO)
	  (match c
	    [(or #\a #\A) 10]
		[(or #\b #\B) 11]
		[(or #\c #\C) 12]
		[(or #\d #\D) 13]
		[(or #\e #\E) 14]
		[(or #\f #\F) 15]
		[_ (error 'hex-char->num "invalid hex char: ~a\n" c)])))
		
(define (hex-str->num hstr)
  (for/fold ([num 0]) ([h (in-string hstr)])
    (+ (* 16 num) (hex-char->num h))))		
```

The `fold/for` form starts with an intermediate result of 0 and then
for each hex digit, multiplies the intermediate result by 16 and adds
to it the base-10 representation of that digit. The `hex-char->num`
function converts a single hex digit to base-10.

Let's take a sample Bitcoin address (from [here][bwiki:addr]) and see
what the base-10 equivalent is (the above code is saved to a file
`base58.rkt`):

[bwiki:addr]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Technical background of version 1 Bitcoin addresses"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "base58.rkt")
    -> (hex-str->num "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    25420294593250030202636073700053352635053786165627414518

Now that we have a base-10 number, it's much easier to compute the
Base58Check representation. Here's an initial attempt at converting to
base-58:

```racket
(define BASE58-CHARS "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
(define (num->base58-char b) (string-ref BASE58-CHARS b))
  
(define (num->base58-str.v0 n)
  (list->string
    (reverse
	  (let loop ([n n])
	    (define-values (q r) (quotient/remainder n 58))
		(if (zero? q)
		    (list (num->base58-char r))
			(cons (num->base58-char r) (loop q))))))))

(define (hex-str->base58-str.v0 hstr) 
  (num->base58-str.v0 (hex-str->num hstr)))
```

The `hex-str->base58-str.v0` function starts by converting the hex
string to a base-10 number using the previously defined
`hex-str->num` function. It then dispatches to `num->base58-str.v0`
to convert the base-10 number to the base-58 digits. The
`num->base58-str.v0` function repeatedly performs `modulo 58` and
integer division operations. The `modulo` operation computes the next
base-58 digit and the division computes the number to use in the next
iteration. The `quotient/remainder` Racket function conveniently
performs both the modulo and division in one step. The base-58 digits
are computed in reverse order so the final operation is to reverse the
digits and convert back to a string.

Let's test our code. Following the same example from the Bitcoin wiki,
we expect the hex address
`00010966776006953D5567439E5E39F86A0D273BEED61967F6` to be `16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM` in Base58Check.

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "base58.rkt")
	-> (hex-str->base58-str.v0 "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

We got the wrong answer! What happened? It turns out that the leading
zeros in the hex address have meaning, but these zeros get lost when
we converted the hex string to a base-10 number. To get the proper
base-58 address, we count the number of leading zeros in the hex
string. The rule is that the base-58 address should have one leading
"1" character per leading zero *byte*, ie, one leading base-58 "1" per
two leading hex "0"s. Here's an updated `hex-str->base58-str` function definition:

```racket
(define (num->base58-str n)
  (if (zero? n) "" (num->base58-str.v0 n)))
																			 
(define (hex-str->base58-str hstr)
  (define num-leading-ones (quotient (count-leading-zeros hstr) 2))
  (define leading-ones (make-string num-leading-ones #\1))
  (string-append leading-ones (hex-str->base58-str.v0 hstr)))
```	  

Trying our example again yields the expected result:

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "base58.rkt")
	-> (hex-str->base58-str "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

### Decoding ###

To convert from base-58 to hex, we do the reverse of the above steps:
convert from base-58 to base-10, and then from base-10 to hex.


TODO:
1. try example -- wrong
2. hex string must be byte-aligned (ie even number of digits)