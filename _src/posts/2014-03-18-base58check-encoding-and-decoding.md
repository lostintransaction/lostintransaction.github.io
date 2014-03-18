    Title: Base58Check Encoding and Decoding
    Date: 2014-03-18T05:44:11
    Tags: Base58Check, Racket, Bitcoin addresses

In previous posts, we looked at
[computing a Bitcoin public key from a private key][LiT:pubfrompriv],
and then [computing a Bitcoin address from a public key]. However, our
experiments dealt with hexadecimal representations of keys and
addresses, which are rarely used except in code. In practice, Bitcoin
addresses use the more human-readable [Base58Check][bwiki:b58]
encoding, which we explore in this post.

[LiT:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/deriving-a-bitcoin-public-key-from-a-private-key/ "Deriving a Bitcoin Public Key From a Private Key"
[LiT:ffi]: http://www.lostintransaction.com/blog/2014/03/15/adding-openssl-bindings-to-racket-via-its-ffi/ "Adding OpenSSL bindings to Racket via its FFI"
[bwiki:b58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Base58Check encoding"

<!-- more -->

Here is the rationale for using Base58Check encoding, taken from
[comments in the Bitcoin reference implementation][bitcoinsrc]:

    // Why base-58 instead of standard base-64 encoding?
    // - Don't want 0OIl characters that look the same in some fonts and
    // could be used to create visually identical looking account numbers.
    // - A string with non-alphanumeric characters is not as easily accepted as an account number.
    // - E-mail usually won't line-break if there's no punctuation to break at.
    // - Double-clicking selects the whole number as one word if it's all alphanumeric.

[bitcoinsrc]: https://github.com/bitcoin/bitcoin/blob/f76c122e2eac8ef66f69d142231bd33c88a24c50/src/base58.h#L7-L12 "src/base58.h"

It seems the goal is to have an address string that is easy for humans
to read and handle. Our code will resemble the Bitcoin C++ code, but
we will use our favorite language [Racket](http://racket-lang.org).

### Encoding ###

Let's figure out how to convert from hexadecimal to Base58Check. It's fairly simple, we just treat a hex string as a base-16 number, and then, to get the digits, we repeatedly compute the [`modulo`] 58 result and divide until we reach zero. 

Unfortunately, it's rare to find `modulo` and division operations for
base-16 numbers so it will be easier to convert to a base-10 number
first. Converting from base-`N` to base-10 is straightforward as well,
we just iterate the digits, repeatedly multiplying by `N` and adding
the next digit, similar to how a number like 4321 = ((4*10 + 3)*10 +
2)*10 + 1. Here's a Racket function `hex-str->number` that converts
from hex to base-10. 

```racket
(define ASCII-ZERO (char->integer #\0))

;; [0-9A-Fa-f] -> Number from 0 to 15
(define (hex-char->number c)
  (if (char-numeric? c)
      (- (char->integer c) ASCII-ZERO)
	  (match c
	    [(or #\a #\A) 10]
		[(or #\b #\B) 11]
		[(or #\c #\C) 12]
		[(or #\d #\D) 13]
		[(or #\e #\E) 14]
		[(or #\f #\F) 15]
		[_ (error 'hex-char->number "invalid hex char: ~a\n" c)])))
		
(define (hex-str->number hstr)
  (for/fold ([num 0]) ([h (in-string hstr)])
    (+ (* 16 num) (hex-char->number h))))		
```

`hex-str->number` relies on a `hex-char->number` function that
converts a single hex digit to base-10. The `fold/for` form does
exactly what we previously decribed. which is iterates the digits of
the hex string and repeatedly multiplies the intermediate result by 16
and adding the base-10 equivalent of the current digit. 

Using a high-level language with arbitrary-precision arithmetic here
is convenient because we avoid dealing with `BIGNUM`s. For fun, let's
take a sample Bitcoin address (from [here][bwiki:addr]) and see what
the base-10 equivalent is (the above code is saved to a file
`bitcoin.rkt`):

[bwiki:addr]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Technical background of version 1 Bitcoin addresses"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "bitcoin.rkt")
    -> (hex-str->number "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    25420294593250030202636073700053352635053786165627414518

Now that we have a base-10 number, it's much easier to compute the
Base58Check equivalent. As previously mentioned, we iterate the digits and repeatedly compute `modulo` 58 and divide. Here's Racket functions that perform the conversion to Base58Check:

```racket
(define BASE58-CHARS "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
(define (num->base58-char b) (string-ref BASE58-CHARS b))

  
(define (number->base58-str.v0 n)
  (list->string
    (reverse
	  (let loop ([n n])
	    (define-values (q r) (quotient/remainder n 58))
		(if (zero? q)
		    (list (num->base58-char r))
			(cons (num->base58-char r) (loop q))))))))

(define (hex-str->base58-str.v0 hstr) 
  (number->base58-str (hex-str->number hstr)))
```

The `base58-char->number` function converts a base-58 character to a
base-10 number by looking up the character's position in the
`BASE58-CHARS` constant string. the `number->base58-str.v0` function consumes a number `n` and repeatedly:

1. computes `n modulo 58` and calls 
2. computes `n / 58` to use in the next iteration, where the division
is integer division

The `quotient/remainder` Racket function computes both steps at
once. This computes both the above steps at once. Finally, the digits
are computed in reverse order, so we reverse the digits and convert
back to a string.

Let's test our code. Following the same example from the Bitcoin wiki,
we expect an address
`00010966776006953D5567439E5E39F86A0D273BEED61967F6` in hex to be an
address `16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM` in Base58Check.

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "bitcoin.rkt")
	-> (hex-str->base58-str.v0 "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

We got the wrong answer! What happened?
