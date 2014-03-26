    Title: Base58Check Encoding and Decoding
    Date: 2014-03-18T05:44:11
    Tags: Base58Check, Racket, Bitcoin addresses

In previous posts, we looked at
[computing a Bitcoin public key from a private key][LiT:pubfrompriv],
and then
[computing a Bitcoin address from a public key][LiT:ffi]. However, our
experiments dealt with hexadecimal representations of keys and
addresses, which is not the representation familiar to most Bitcoin
users. In practice, Bitcoin addresses use the more human-readable
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
handle. Let's implement Base58Check encoding and decoding. We use
[Racket](http://racket-lang.org) to avoid the hassle of `BIGNUM`s.

### Encoding ###

To convert from hexadecimal to Base58Check, we repeat `modulo 58` and
division operations on the hex string until we reach zero. Racket (nor
any other language) does not come with modulo and division operations
on hex strings, however, so it's much easier to convert to a base-10
number first. Here's a Racket function `hex-str->num` that converts
from hex to base-10.

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
zeros matter when a hex string is viewed as a Bitcoin address, but not
when the hex string is viewed as a number. When we converted from hex
to base-10, we were treating the hex string as a number and the
leading zeros got lost. 

To complete the base-58 conversion, we count the number of leading
zeros in the hex string. The Bitcoin reference implementation adds one
leading `1` character to the base-58 address for each leading zero
*byte* in the hex string, ie, one leading base-58 `1` per two leading
hex "0"s. Here's an updated `hex-str->base58-str` function definition:

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

```racket
(define (num->hex-char n)
  (when (or (< n 0) (>= n 16))
    (error 'num->hex-char "cannot convert to hex: ~a\n" n))
  (string-ref HEX-CHARS n))
(define (num->hex-str n)
  (if (zero? n) "" 
      (list->string
	  (reverse
	    (let loop ([n n])
		  (define-values (q r) (quotient/remainder n 16))
		  (if (zero? q)
              (list (num->hex-char r))
			  (cons (num->hex-char r) (loop q))))))))
																			 
(define (base58-str->num str)
  (for/fold ([num 0]) ([d str]) (+ (* 58 num) (base58-char->num d))))
								
(define (count-leading ch str)
  (for/sum ([c str] #:break (not (eq? c ch))) 1))
  
(define (base58-str->hex-str b58str)
  (define hex-str (base58-str->hex-str/num b58str))
  (define zeros-from-b58str (* 2 (count-leading #\1 b58str)))
  (define num-leading-zeros
  (if (even? (string-length hex-str))
      zeros-from-b58str
	  (add1 zeros-from-b58str))) ; to make hex str byte aligned
  (define leading-zeros-str (make-string num-leading-zeros #\0))
  (string-append leading-zeros-str hex-str))
(define (base58-str->hex-str/num b58str)
  (num->hex-str (base58-str->num b58str)))
```

And trying it on our example returns the expected result:

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "base58.rkt")
    -> (base58-str->hex-str "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
    "00010966776006953D5567439E5E39F86A0D273BEED61967F6"
   
<!--TODO:
1. hex string must be byte-aligned (ie even number of digits)-->
