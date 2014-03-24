    Title: Adding OpenSSL bindings to Racket via its FFI
    Date: 2014-03-15T04:09:45
    Tags: OpenSSL, C, Racket, FFI, hashes, SHA, RIPEMD

C is great for many programming tasks but sometimes it's nice to use a
higher-level language that automatically handles things like
arbitrary-precision arithmetic and memory
management. [Racket](http://racket-lang.org), a LISP dialect, has
linguistic support for these features (and more) and I enjoy using it
to experiment with Bitcoin. 

Unfortunately, Racket doesn't have a complete crypto library. It does
have, however, an [FFI][racketffi] that enables Racket code to
directly call C functions. In this post, I create Racket bindings for
two important hashing functions used by Bitcoin, [SHA-256][wiki:sha]
and [RIPEMD-160][wiki:ripemd].

[racketffi]: http://docs.racket-lang.org/foreign/index.html "Racket FFI"
[wiki:sha]: http://en.wikipedia.org/wiki/SHA-2 "Wikipedia: SHA-2"
[wiki:ripemd]: http://en.wikipedia.org/wiki/RIPEMD "Wikipedia: RIPEMD"

<!-- more -->

### `ffi-lib` ###

The [`ffi-lib`][racket:ffilib] function creates a Racket value through
which programmers can access functions in the specified C library. For
example, the following code evaluates to a Racket value for the
OpenSSL `libcrypto` library:

```racket
(ffi-lib '(so "libcrypto") '("" "1.0.1e" "1.0.0" "1.0" "0.9.8b" "0.9.8" "0.9.7"))
```

Here the first argument to `ffi-lib` specifies a dynamic C library and
the second argument is a list of acceptable version numbers. (Check
the [`ffi-lib` documentation][racket:ffilib] for other possible use
cases.)

The standard Racket distribution pre-defines an identifier (also named
`librypto`) that is bound to the `libcrypto` library (Racket comes
with wrapper functions for some `libcrypto` C functions, but not for
`SHA256` or `RIPEMD160`).

[racket:ffilib]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=ffi-lib#%28def._%28%28lib._ffi%2Funsafe..rkt%29._ffi-lib%29%29 "Racket docs: ffi-lib"
[plt:libcrypto]: https://github.com/plt/racket/blob/8b4c5d3debbe41c90e37e5ffdc55fb8ab3635f92/racket/collects/openssl/libcrypto.rkt "Racket source: openssl/libcrypto.rkt"

### `get-ffi-obj` ###

Let's create a Racket wrapper function for the
[`SHA256` C function][openssl:sha256]. Here's the header:

```C
unsigned char *SHA256( const unsigned char *d, size_t n, unsigned char *md );
```

To create a Racket wrapper function, we use
[`get-ffi-obj`][racket:getffiobj]. Here's one possible definition of a
`sha256` Racket function that calls the `SHA256` C function:

```racket
(define SHA256-DIGEST-LEN 32)

(define sha256
  (get-ffi-obj
    'SHA256 libcrypto
    (_fun [input     : _bytes]
          [input-len : _ulong = (bytes-length input)]
          [output    : (_bytes o SHA256-DIGEST-LEN)]
          -> (_bytes o SHA256-DIGEST-LEN))))
```

The first argument to `get-ffi-obj` is the name of the C function and
the second argument is the library value that we created earlier with
`ffi-lib`. The third argument is the type, which specifies how to
mediate between Racket and C values. [`_fun`][racket:fun] is the
function type and in this case the function has three arguments
(conventionally delimited with brackets).

Examining the types of the arguments:

1. The first argument to the `SHA256` C function is an array of input
bytes. Accordingly, we give `get-ffi-obj` a `_bytes` type for this
argument.

2. The second argument is the length of the input byte array. The `=`
tells Racket how to calculate this argument automatically. Thus a
caller of the `sha256` Racket function need not provide this argument.

3. The third argument is the output byte array. The `o` indicates a
return pointer and is followed by the expected length of the output
array, which should be 32 bytes. We define a constant
`SHA256-DIGEST-LEN` which is analogous to
[the `SHA256_DIGEST_LENGTH` constant][openssl:sha256const] in the C
library.

[openssl:sha256]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/sha/sha.h;h=8a6bf4bbbb1dbef37869fc162ce1c2cacfebeb1d;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l155 "OpenSSL source: crypto/sha/sha.h"
[racket:getffiobj]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=get-ffi-obj#%28def._%28%28lib._ffi%2Funsafe..rkt%29._get-ffi-obj%29%29 "Racket docs: get-ffi-obj"
[racket:fun]: http://docs.racket-lang.org/foreign/foreign_procedures.html?q=_fun#%28form._%28%28lib._ffi%2Funsafe..rkt%29.__fun%29%29 "Racket docs: _fun"
[openssl:sha256const]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/sha/sha.h;h=8a6bf4bbbb1dbef37869fc162ce1c2cacfebeb1d;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l133 "OpenSSL source: crypto/sha/sha.h"

### All Together

Here's some code defining a Racket module that exports functions named
`sha256` and `ripemd160`. Note that the functions that call directly
to the C functions are now named `sha256/bytes` and `ripemd160/bytes`,
and these functions consume and produce bytes. We additionally define
`sha256` and `ripemd160` functions which have optional keyword
arguments for conversion of the input and output. These functions
consume and produce hexadecimal strings by default.

```racket
#lang racket/base
(require ffi/unsafe openssl/libcrypto)
(require (only-in openssl/sha1 hex-string->bytes
                               bytes->hex-string))
(provide (all-defined-out))

(define SHA256-DIGEST-LEN 32)
(define RIPEMD160-DIGEST-LEN 20)

; from crypto/sha/sha.h:
;   unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);
(define sha256/bytes
  (get-ffi-obj
  'SHA256 libcrypto
  (_fun [input     : _bytes]
        [input-len : _ulong = (bytes-length input)]
		[output    : (_bytes o SHA256-DIGEST-LEN)]
        -> (_bytes o SHA256-DIGEST-LEN))))

(define (sha256 input #:convert-input  [input->bytes hex-string->bytes]
                      #:convert-output [bytes->output bytes->hex-string])
  (bytes->output (sha256/bytes (input->bytes input))))

; from crypto/ripemd/ripemd.h
;   unsigned char *RIPEMD160(const unsigned char *d, size_t n, unsigned char *md);
(define ripemd160/bytes
  (get-ffi-obj
  'RIPEMD160 libcrypto
  (_fun [input     : _bytes]
        [input-len : _ulong = (bytes-length input)]
        [output    : (_bytes o RIPEMD160-DIGEST-LEN)]
        -> (_bytes o RIPEMD160-DIGEST-LEN))))
		
(define (ripemd160 input #:convert-input  [input->bytes hex-string->bytes]
                         #:convert-output [bytes->output bytes->hex-string])
  (bytes->output (ripemd160/bytes (input->bytes input))))
```

### Testing ###

To test our wrapper functions, let's see if we can duplicate
[this example from the Bitcoin wiki][bwiki], which shows how to
convert a Bitcoin private key into a public address. We covered
[how to derive a public key from a private key][lit:pubfrompriv] in
a previous post, so we start with the public key here.

[bwiki]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin Wiki: Technical background of version 1 Bitcoin addresses"
[lit:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/deriving-a-bitcoin-public-key-from-a-private-key/ "Deriving a Bitcoin Public Key From a Private Key"

For ease of comparison, here's the sequence of expected hashes, copied
from the Bitcoin wiki example:

1. public key: `0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`
2. SHA-256: `600FFE422B4E00731A59557A5CCA46CC183944191006324A447BDB2D98D4B408`
3. RIPEMD-160: `010966776006953D5567439E5E39F86A0D273BEE`
4. prepend `0x00`: `00010966776006953D5567439E5E39F86A0D273BEE`
5. SHA-256: `445C7A8007A93D8733188288BB320A8FE2DEBD2AE1B47F0F50BC10BAE845C094`
6. SHA-256 (checksum is first 4 bytes): `D61967F63C7DD183914A4AE452C9F6AD5D462CE3D277798075B107615C1A8A30`
7. checksum + #4 = (hex) address: `00010966776006953D5567439E5E39F86A0D273BEED61967F6`

We can use [the Racket REPL][racket:repl], and the code above (which I
saved to a file `crypto.rkt`) to get the same results:

[racket:repl]: http://docs.racket-lang.org/guide/intro.html?q=repl#%28tech._repl%29 "Interacting with Racket"

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "crypto.rkt")
	-> (define pub-key "0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6")
	-> (sha256 pub-key)
	"600ffe422b4e00731a59557a5cca46cc183944191006324a447bdb2d98d4b408"
	-> (ripemd160 (sha256 pub-key))
	"010966776006953d5567439e5e39f86a0d273bee"
	-> (define hash160 (ripemd160 (sha256 pub-key)))
	-> (define hash160/extended (string-append "00" hash160))
	-> (sha256 hash160/extended)
	"445c7a8007a93d8733188288bb320a8fe2debd2ae1b47f0f50bc10bae845c094"
	-> (sha256 (sha256 hash160/extended))
	"d61967f63c7dd183914a4ae452c9f6ad5d462ce3d277798075b107615c1a8a30"
	-> (define checksum (substring (sha256 (sha256 hash160/extended)) 0 8))
	-> checksum
	"d61967f6"
	-> (define address/hex (string-append hash160/extended checksum))
	-> address/hex
	"00010966776006953d5567439e5e39f86a0d273beed61967f6"
	   
The last command computes the Bitcoin address in hexadecimal
format. The Bitcoin wiki article performs one more step to convert to
[Base58Check encoding][bwiki:b58], which is the standard
representation for Bitcoin addresses. We'll look at Base58Check
encoding in the next post!

[bwiki:b58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Bitcoin wiki: Base58Check encoding"

### Software ###

In this post, I'm using OpenSSL 1.0.1e, Racket 6.0.0.3, and Debian
7.0.
