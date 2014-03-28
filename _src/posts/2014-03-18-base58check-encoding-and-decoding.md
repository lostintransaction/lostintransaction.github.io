    Title: Base58Check Encoding and Decoding
    Date: 2014-03-18T05:44:11
    Tags: Base58Check, Racket, Bitcoin addresses

In previous posts, we looked at
[computing a Bitcoin public key from a private key][LiT:pubfrompriv],
and [computing a Bitcoin address from a public key][LiT:ffi]. However,
these posts dealt with hexadecimal representations of keys and
addresses, which is not the representation familiar to most Bitcoin
users. Bitcoin addresses more commonly are encoded as
[Base58Check][bwiki:b58] strings, which we explore in this post.

[LiT:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/deriving-a-bitcoin-public-key-from-a-private-key/ "Deriving a Bitcoin Public Key From a Private Key"
[LiT:ffi]: http://www.lostintransaction.com/blog/2014/03/15/adding-openssl-bindings-to-racket-via-its-ffi/ "Adding OpenSSL bindings to Racket via its FFI"
[bwiki:b58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Base58Check encoding"

<!-- more -->

The [Bitcoin reference code][bitcoinsrc] provides the following
rationale for using Base58Check (over base-64):

    // Why base-58 instead of standard base-64 encoding?
    // - Don't want 0OIl characters that look the same in some fonts and
    //      could be used to create visually identical looking account numbers.
    // - A string with non-alphanumeric characters is not as easily accepted as an account number.
    // - E-mail usually won't line-break if there's no punctuation to break at.
    // - Double-clicking selects the whole number as one word if it's all alphanumeric.

[bitcoinsrc]: https://github.com/bitcoin/bitcoin/blob/f76c122e2eac8ef66f69d142231bd33c88a24c50/src/base58.h#L7-L12 "src/base58.h"

Essentially, the goal with Base58Check is to make it easier for humans
to read and handle Bitcoin addresses. Let's implement Base58Check
encoding and decoding. We'll use [Racket](http://racket-lang.org),
which let's us avoid the hassle of dealing with `BIGNUM`s.

### Encoding ###

To convert a hex string to Base58Check, we need to repeatedly perform
modulo and division operations on the string. However, Racket doesn't
come with modulo and division operations on hex strings so it'll be
easier to convert to a base-10 number first. Here's a Racket function
`hex-str->num` that converts from hex to base-10.

```racket
(define HEX-CHARS "0123456789ABCDEF")

(define (upcase=? c1 c2) (char=? (char-upcase c1) (char-upcase c2)))

(define (hex-char->num ch)
  (define index 
    (for/first ([(c n) (in-indexed HEX-CHARS)] #:when (upcase=? c ch)) n))
  (or index (error 'hex-char->num "invalid hex char: ~a\n" ch)))
	  
(define (hex-str->num hstr)
  (for/fold ([num 0]) ([ch (in-string hstr)]) 
    (+ (* 16 num) (hex-char->num ch))))
```

The `fold/for` form defines an intermediate result `num` that is
initially 0 and then for each hex character, multiplies the
intermediate result by 16 and adds to it the base-10 representation of
that hex character, as computed by `hex-char->num`. The
`hex-char->num` function converts a hex character to a number by
computing the position of the character in the `HEX-CHARS` constant
string, or throws an error if the input character is not valid
hex. Note that `hex-char->num` accepts both upper and lowercase hex
characters.

Let's see what the (hex) Bitcoin address from
[this Bitcoin Wiki article][bwiki:addr]) is in base-10 (the above code
is saved to a file `base58.rkt` with `hex-str->num` exported):

[bwiki:addr]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Technical background of version 1 Bitcoin addresses"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "base58.rkt")
    -> (hex-str->num "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    25420294593250030202636073700053352635053786165627414518

We can now use base-10 modulo and divide to convert from base-10 to
Base58Check. Here's an initial attempt at converting to base-58:

```racket
(define BASE58-CHARS "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

(define (num->base58-char n)
  (when (or (< n 0) (>= n 58))
    (error 'num->base58-char "cannot convert to base-58: ~a\n" n))
  (string-ref BASE58-CHARS n))
  
(define (num->base58-str.v0 n)
  (list->string
    (reverse
	  (let loop ([n n])
	    (define-values (q r) (quotient/remainder n 58))
		(if (zero? q)
            (list (num->base58-char r))
			(cons (num->base58-char r) (loop q)))))))

(define (hex-str->base58-str.v0 hstr) 
  (num->base58-str (hex-str->num hstr)))
```

The `hex-str->base58-str.v0` function starts by converting the hex
string to a base-10 number using the previously defined
`hex-str->num`. It then calls `num->base58-str.v0` to convert the
base-10 number to base-58. The `num->base58-str.v0` function
repeatedly performs `modulo 58` and integer division operations on the
given number in a loop. Giving the result of the `modulo` operation to
`num->base58-char` produces the next base-58 digit and the division
computes the number to use in the next iteration of the loop. The
`quotient/remainder` Racket function conveniently performs both the
modulo and division in one step. The end result of the `loop` is a
list of base-58 digits. The digits are computed in reverse order so
they are reversed before converting back to a string.

Let's test our code. Following
[the same example from the Bitcoin wiki][bwiki:addr], the hex address
`00010966776006953D5567439E5E39F86A0D273BEED61967F6` in Base58Check is
`16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM`.

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "base58.rkt")
	-> (hex-str->base58-str.v0 "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

We got the wrong answer! What happened? It turns out that the leading
zeros in a hex string matter when the string is viewed as a Bitcoin
address. But when we converted to base-10, the leading zeros got lost
since they don't matter for numbers.

To complete the base-58 conversion according to the Bitcoin reference
code, we count the number of leading zeros in the hex string and add
one leading '1' character to the base-58 address for each leading zero
*byte* in the hex string, ie, we add one leading base-58 '1' per two
leading hex '0's. Here's an updated conversion function:

```racket
(define (count-leading-zeros str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\0 c))) 1))
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

To convert from base-58 back to hex, we reverse the above steps. We
first convert from base-58 to base-10 and then from base-10 to
hex. 

The conversion from hex or base-58 strings into numbers is
similar, so we can abstract the common parts into a separate function:

```racket
(define (baseN-char->num ch #:CHARS [CHARS ""] #:c=? [c=? char=?])
  (define base (string-length CHARS))
  (define index (for/first ([(c n) (in-indexed CHARS)] #:when (c=? c ch)) n))
  (or index (error 'char->num "invalid base-~a char: ~a\n" base ch)))

(define HEX-CHARS "0123456789ABCDEF")
(define (upcase=? c1 c2) (char=? (char-upcase c1) (char-upcase c2)))

(define (hex-char->num c) 
  (baseN-char->num c #:CHARS HEX-CHARS #:c=? upcase=?))
(define (base58-char->num c) 
  (baseN-char->num c #:CHARS BASE58-CHARS))
			
(define (baseN-str->num str #:base [N 10] #:digit->num [digit->num identity])
  (for/fold ([num 0]) ([d str]) (+ (* N num) (digit->num d))))

(define (hex-str->num hstr)
  (baseN-str->num hstr #:base 16 #:digit->num hex-char->num))
(define (base58-str->num b58str)
  (baseN-str->num b58str #:base 58 #:digit->num base58-char->num))
```

Similarly, the conversion from base-10 to hex resembles the conversion
from base-10 to base-58:

```racket
(define (num->baseN-str n #:base [N 10] #:num->char [num->char identity])
  (if (zero? n) "" (nonzero-num->baseN-str n #:base N #:num->char num->char)))
(define (nonzero-num->baseN-str n #:base [N 10] #:num->char [num->char identity])
  (list->string
    (reverse
      (let loop ([n n])
        (define-values (q r) (quotient/remainder n N))
        (if (zero? q)
            (list (num->char r))
            (cons (num->char r) (loop q)))))))

(define (num->base58-str n)
  (num->baseN-str n #:base 58 #:num->char num->base58-char))
(define (num->hex-str n)
  (num->baseN-str n #:base 16 #:num->char num->hex-char))
```

Finally we put the functions together to complete the conversion. Of
course, we can't forget to add back the leading zeros, like before.

```racket
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
    -> (hex-str->base58-str "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"
	-> (base58-str->hex-str "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
    "00010966776006953D5567439E5E39F86A0D273BEED61967F6"

### Software

All the code from this post
[may be downloaded here](http://www.lostintransaction.com/code/base58.rkt).
Examples were executed with Racket 6.0.0.3 running in Debian 7.0.

<!--todo: explain decode code-->
