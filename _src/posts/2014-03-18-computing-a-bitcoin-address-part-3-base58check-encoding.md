    Title: Computing a Bitcoin Address, Part 3: Base58Check Encoding
    Date: 2014-03-18T05:44:11
    Tags: Base58Check, Bitcoin addresses, Racket

In previous posts, we looked at
[computing a Bitcoin public key from a private key][LiT:pubfrompriv],
and [computing a Bitcoin address from a public key][LiT:ffi]. However,
these posts dealt with keys and addresses in hexadecimal (hex) form,
which is not the representation familiar to most Bitcoin
users. Bitcoin addresses more commonly are encoded as
[Base58Check][bwiki:b58] strings, which we explore in this post.

[LiT:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/computing-a-bitcoin-address-part-1-private-to-public-key/ "Computing a Bitcoin Address, Part 1: Private to Public Key"
[LiT:ffi]: http://www.lostintransaction.com/blog/2014/03/15/computing-a-bitcoin-address-part-2-public-key-to-hex-address/ "Computing a Bitcoin Address, Part 2: Public Key to (Hex) Address"
[bwiki:b58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Base58Check encoding"

<!-- more -->

> This is the third post in a four-part titled series "Computing a Bitcoin Address".
> Here are all the articles in the series:
>
> * Part 1: [Private to Public Key](http://www.lostintransaction.com/blog/2014/03/14/computing-a-bitcoin-address-part-1-private-to-public-key/)
> * Part 2: [Public Key to (Hex) Address](http://www.lostintransaction.com/blog/2014/03/15/computing-a-bitcoin-address-part-2-public-key-to-hex-address/)
> * Part 3: [Base58Check Encoding](http://www.lostintransaction.com/blog/2014/03/18/computing-a-bitcoin-address-part-3-base58check-encoding/) (this post)
> * Part 4: [Wallet Import Format (WIF)](http://www.lostintransaction.com/blog/2014/04/09/computing-a-bitcoin-address-part-4-wallet-import-format-wif/)

The [Bitcoin reference code][bitcoinsrc] provides the following
rationale for using Base58Check (instead of a more common base-64
encoding):

    // Why base-58 instead of standard base-64 encoding?
    // - Don't want 0OIl characters that look the same in some fonts and
    //      could be used to create visually identical looking account numbers.
    // - A string with non-alphanumeric characters is not as easily accepted as an account number.
    // - E-mail usually won't line-break if there's no punctuation to break at.
    // - Double-clicking selects the whole number as one word if it's all alphanumeric.

[bitcoinsrc]: https://github.com/bitcoin/bitcoin/blob/f76c122e2eac8ef66f69d142231bd33c88a24c50/src/base58.h#L7-L12 "src/base58.h"

Essentially, the goal with Base58Check is to make it easier for humans
to read and handle Bitcoin addresses. In this post, instead of the C++
used in the Bitcoin reference, we implement Base58Check encoding and
decoding using [Racket](http://racket-lang.org), which lets us avoid
the hassle of dealing with `BIGNUM` numbers.

### Encoding ###

To convert a hex string to Base58Check, we need to repeatedly perform
modulo and division operations on the string. However, Racket doesn't
come with modulo and division operations on hex strings so it'll be
easier to convert to a base-10 number first. Here's a Racket function
`hex-str->num` that converts from hex to base-10.

```racket
(define HEX-CHARS "0123456789ABCDEF")

; case-insensitive character equality operator
(define (anycase=? c1 c2) (char=? (char-upcase c1) (char-upcase c2)))

; convert hex digit to base-10 number
(define (hex-char->num ch)
  (define index 
    (for/first ([(c n) (in-indexed HEX-CHARS)] #:when (anycase=? c ch)) n))
  (or index (error 'hex-char->num "invalid hex char: ~a\n" ch)))
	  
; convert hex string to base-10 number
(define (hex-str->num hstr)
  (for/fold ([num 0]) ([ch (in-string hstr)]) 
    (+ (* 16 num) (hex-char->num ch))))
```

The `fold/for` form defines an intermediate result `num` that is
initially 0 and then for each hex character in the input `hstr`,
multiplies the intermediate result by 16 and adds to it the base-10
representation of that hex character, as computed by
`hex-char->num`. The `hex-char->num` function converts a hex character
to a number by computing the position of the character in the
`HEX-CHARS` constant string (or throws an error if the input character
is not valid hex). Note that `hex-char->num` accepts both upper and
lowercase hex characters, and uses the case-insensitive `anycase=?` to
compare characters for equality.

Let's see what the (hex) Bitcoin address from
[this Bitcoin Wiki article][bwiki:addr] (step 8) is in base-10 (the
above code is saved to a file `base58.rkt` with `hex-str->num`
exported):

[bwiki:addr]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Technical background of version 1 Bitcoin addresses"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "base58.rkt")
    -> (hex-str->num "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    25420294593250030202636073700053352635053786165627414518

We can now use standard (base-10) modulo and divide operations to
convert from base-10 to Base58Check. Here's an initial attempt at
converting to base-58:

```racket
(define BASE58-CHARS "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

; convert base10 number to base58 digit
(define (num->base58-char n)
  (when (or (< n 0) (>= n 58))
    (error 'num->base58-char "cannot convert to base-58: ~a\n" n))
  (string-ref BASE58-CHARS n))
  
;; convert base10 number to base58check string (first attempt)
(define (num->base58-str.v0 n)
  (list->string
    (reverse
      (let loop ([n n])
        (define-values (q r) (quotient/remainder n 58))
        (if (zero? q)
            (list (num->base58-char r))
            (cons (num->base58-char r) (loop q)))))))

; convert hex string to base58check string (first attempt)
(define (hex-str->base58-str.v0 hstr) 
  (num->base58-str.v0 (hex-str->num hstr)))
```

The `hex-str->base58-str.v0` function first converts its hex string
input to a base-10 number using the previously defined
`hex-str->num`. It then calls `num->base58-str.v0` to convert the
base-10 number to base-58. The `num->base58-str.v0` function
repeatedly performs `modulo 58` and integer division operations on the
given number --- the `quotient/remainder` Racket function conveniently
performs both these operations in one step. Passing the `modulo`
result (ie the remainder `r`) to `num->base58-char` gives in the next
base-58 digit and the division result (ie the quotient `q`) is used in
the next `loop` iteration. The end result of the `loop` is a list of
base-58 digits. The digits are computed in reverse order so they are
reversed before converting back to a string.

Let's test our code. Following
[the same example from the Bitcoin wiki][bwiki:addr], the hex address
`00010966776006953D5567439E5E39F86A0D273BEED61967F6` is
`16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM` in Base58Check.

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "base58.rkt")
	-> (hex-str->base58-str.v0 "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

Our initial attempt produces the wrong answer! What happened? It turns
out that the leading zeros in a hex string matter when the string is
viewed as a Bitcoin address. But when we converted to base-10, the
leading zeros got dropped since they don't matter for numbers.

To complete the base-58 conversion, following the Bitcoin reference
code, we count the number of leading zeros in the hex string and add
one leading '1' character to the base-58 address for each leading zero
*byte* in the hex string, ie, we add one leading base-58 '1' per two
leading hex '0's. Here's an updated conversion function:

```racket
(define (count-leading-zeros str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\0 c))) 1))

; converts base10 number to base58check string
(define (num->base58-str n) 
  (if (zero? n) "" (num->base58-str.v0 n)))
  
; converts hex string to base58check string
(define (hex-str->base58-str hstr)
  (define num-leading-ones (quotient (count-leading-zeros hstr) 2))
  (define leading-ones (make-string num-leading-ones #\1))
  (string-append leading-ones (num->base58-str (hex-str->num hstr))))
```

Trying our example again yields the expected result:

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "base58.rkt")
	-> (hex-str->base58-str "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
	"16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"

### Decoding ###

To convert from base-58 back to hex, we reverse the above steps. We
first convert from base-58 to base-10 and then from base-10 to hex.

The conversion from base-58 strings into base-10 numbers looks a lot
like the `hex-str->num` and `hex-char->num` functions we defined above:

```racket
; converts base58check digit to base10 number
(define (base58-char->num ch)
  (define index
    (for/first ([(c n) (in-indexed BASE58-CHARS)] #:when (char=? c ch)) n))
  (or index (error 'base58-char->num "invalid base58 char: ~a\n" ch)))

; converts base58check string to base10 number
(define (base58-str->num b58str)
  (for/fold ([num 0]) ([ch (in-string b58str)])
    (+ (* 58 num) (base58-char->num ch))))
```

Note that unlike `hex-char->num`, `base58-char->num` is case-sensitive.

Similarly, the conversion from base-10 to hex looks mostly like the
`num->base58-str` function above:

```racket
; convert base10 number to hex digit
(define (num->hex-char n)
  (when (or (< n 0) (>= n 16))
    (error 'num->hex-char "cannot convert to hex: ~a\n" n))
  (string-ref HEX-CHARS n))

; convert base10 number to hex string
(define (num->hex-str n)
  (if (zero? n) ""
      (list->string
        (reverse
          (let loop ([n n])
            (define-values (q r) (quotient/remainder n 16))
            (if (zero? q)
                (list (num->hex-char r))
                (cons (num->hex-char r) (loop q))))))))
```

Putting it all together gives us a `base58-str->hex-str` decoding
function. This time we don't forget to count the leading digits, '1's
here instead of '0's. Note that we add an extra '0' to odd-length hex
strings so the result is always byte-aligned.

```racket
(define (count-leading-ones str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\1 c))) 1))
  
; converts a base58check string to a hex string
(define (base58-str->hex-str b58str)
  (define hex-str/no-leading-zeros (num->hex-str (base58-str->num b58str)))
  (define num-leading-ones (count-leading-ones b58str))
  (define num-leading-zeros
    (if (even? (string-length hex-str/no-leading-zeros))
        (* num-leading-ones 2)
        (add1 (* num-leading-ones 2)))) ; add extra 0 to byte-align
  (define leading-zeros (make-string num-leading-zeros #\0))
  (string-append leading-zeros hex-str/no-leading-zeros))
```

And trying it on our [example][bwik:addr] returns the expected results
(the `^` token in the
[Racket Extended REPL](http://docs.racket-lang.org/xrepl/index.html)
is bound to the last printed value):

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "base58.rkt")
	-> (define addr/hex "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
    -> (hex-str->base58-str addr/hex)
    "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM"
	-> (define addr/base58 ^)
    -> (base58-str->hex-str ^)
    "00010966776006953D5567439E5E39F86A0D273BEED61967F6"
	-> (equal? addr/hex ^)
	#t
    -> (equal? (base58-str->hex-str (hex-str->base58-str addr/hex)) addr/hex)
    #t
    -> (equal? (hex-str->base58-str (base58-str->hex-str addr/base58)) addr/base58)
    #t
   
### Software

All the code from this post
[is available here](http://www.lostintransaction.com/code/base58.rkt).
Examples were executed with Racket 6.0.0.3, running in Debian 7.0.

