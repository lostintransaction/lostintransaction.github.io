    Title: Adding OpenSSL bindings to Racket via its FFI
    Date: 2014-03-15T04:09:45
    Tags: OpenSSL, C, Racket, FFI, hashes, SHA, RIPEMD

Programming in C is often useful but it's also occasionally nice to
program with a higher-level language where you don't need to
constantly worry about things like overflow or freeing memory. I enjoy
using [Racket](http://racket-lang.org), a LISP dialect, and I use it
to experiment with Bitcoin.

Unfortunately, Racket doesn't have a complete crypto library, but it
does have an [FFI][racketffi] that enables Racket code to directly
call C functions. In this post, I create Racket bindings for two
important hashing functions used by Bitcoin, [SHA-256][wiki:sha] and
[RIPEMD-160][wiki:ripemd].

[racketffi]: http://docs.racket-lang.org/foreign/index.html "Racket FFI"
[wiki:sha]: http://en.wikipedia.org/wiki/SHA-2 "Wikipedia: SHA-2"
[wiki:ripemd]: http://en.wikipedia.org/wiki/RIPEMD "Wikipedia: RIPEMD"

<!-- more -->

The [`ffi-lib`][racket:ffilib] Racket function in the `ffi/unsafe`
module creates a Racket value representing the given C library. Racket
actually already defines [an identifier `libcrypto`][plt:libcrypto],
which is bound to a value representing the OpenSSL `libcrypto` library
(Racket already has some wrapper functions that call `libcrypto` C
functions, but not for `SHA256` or `RIPEMD160`). Here's the exact call
to `ffi-lib`:

```racket
(define libcrypto
  (ffi-lib libcrypto-so '("" "1.0.1e" "1.0.0" "1.0" "0.9.8b" "0.9.8" "0.9.7")))
```

The first argument is the name of the C library and the second
argument is a list of acceptable versions.

[racket:ffilib]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=ffi-lib#%28def._%28%28lib._ffi%2Funsafe..rkt%29._ffi-lib%29%29 "Racket docs: ffi-lib"
[plt:libcrypto]: https://github.com/plt/racket/blob/8b4c5d3debbe41c90e37e5ffdc55fb8ab3635f92/racket/collects/openssl/libcrypto.rkt "Racket source: openssl/libcrypto.rkt"

Let's create a Racket wrapper function for the
[`SHA256`][openssl:sha256] C function. Here's the C header:

```C
unsigned char *SHA256( const unsigned char *d, size_t n, unsigned char *md );
```

To create a Racket wrapper function, we use the
[`get-ffi-obj`][racket:getffiobj] Racket function. Here's one possible
way to define a Racket `sha256` function that calls the C `SHA256`
function:

```racket
(define sha256
  (get-ffi-obj
    'SHA256 libcrypto
	(_fun [input     : _bytes]
	      [input-len : _ulong = (bytes-length input)]
		  [output    : (_bytes o SHA256-DIGEST-LEN)]
		  -> (_bytes o SHA256-DIGEST-LEN))))
```

The first argument to `get-ffi-obj` is the name of the C function and
the second is the library hook that we created with `ffi-lib`. The
third argument is the type, which specifies how to mediate between
Racket and C values. [`_fun`][racket:fun] specifies a funtion type and
in this case the function has three arguments (each in brackets).

Examining the arguments:

1. The first argument to the C `SHA256` function is an array of input
bytes. Accordingly, `get-ffi-obj` specifies this with a `_bytes` type.

2. The second argument is the length of the input byte array. The `=`
tells Racket how to calculate this argument automatically. This means
that a caller of the Racket `sha256` wrapper function only needs to
provide the input bytes and not an additional length argument.

3. The third argument is the output byte array. In Racket, the `o`
indicates a return pointer and the `SHA256-DIGEST-LEN` indicates the
expected number of output bytes.

[openssl:sha256]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/sha/sha.h;h=8a6bf4bbbb1dbef37869fc162ce1c2cacfebeb1d;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l155 "OpenSSL source: crypto/sha/sha.h"
[racket:getffiobj]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=get-ffi-obj#%28def._%28%28lib._ffi%2Funsafe..rkt%29._get-ffi-obj%29%29 "Racket docs: get-ffi-obj"
[racket:fun]: http://docs.racket-lang.org/foreign/foreign_procedures.html?q=_fun#%28form._%28%28lib._ffi%2Funsafe..rkt%29.__fun%29%29 "Racket docs: _fun"

Here's the entire code to define a Racket module that exports `sha256`
and `ripemd160` wrapper functions. Note that the functions that call
to the C functions are now named `sha256/bytes` and `ripemd160/bytes`,
and these functions consume and produce bytes. We additionally define
`sha256` and `ripemd160` functions which have optional keyword
arguments for conversion of the input and output. `sha256` and
`ripemd160` consume hexadecimal strings by default.


### Testing ###

To test our wrapper functions, let's see if we can duplicate [this example][bwiki], which converts a Bitcoin private key into an address. We covered [how to calculate a public key from a private key][lit:pubfrompriv] in a previous post, so we start with the public key.

[bwiki]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin Wiki: Technical background of version 1 Bitcoin addresses"
[lit:pubfrompriv]: http://www.lostintransaction.com/blog/2014/03/14/deriving-a-bitcoin-public-key-from-a-private-key/ "Deriving a Bitcoin Public Key From a Private Key"

For ease of comparison, here's the sequence of expected hashes, copied
from the Bitcoin wiki example:

1. public key: `0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`
2. SHA-256: `600FFE422B4E00731A59557A5CCA46CC183944191006324A447BDB2D98D4B408`
3. RIPEMD-160: `010966776006953D5567439E5E39F86A0D273BEE`
4. prepend `0x00`: `00010966776006953D5567439E5E39F86A0D273BEE`
5. SHA-256: `445C7A8007A93D8733188288BB320A8FE2DEBD2AE1B47F0F50BC10BAE845C094`
6. SHA-256 (bold checksum): `__D61967F6__3C7DD183914A4AE452C9F6AD5D462CE3D277798075B107615C1A8A30`
7. checksum + #4 = (hex) address: `00010966776006953D5567439E5E39F86A0D273BEED61967F6`

And here's what the computations look like with our new library (using
the Racket REPL):

    $ racket
	Welcome to Racket v6.0.0.3.
	-> (require "crypto.rkt")
	-> (define pub-key "0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6")
	-> (sha256 pub-key)
	"600ffe422b4e00731a59557a5cca46cc183944191006324a447bdb2d98d4b408"
	-> (ripemd160 (sha256 pub-key))
	"010966776006953d5567439e5e39f86a0d273bee"
	-> (define hash160 (ripemd160 (sha256 pub-key)))
	-> (sha256 (string-append "00" hash160))
	"445c7a8007a93d8733188288bb320a8fe2debd2ae1b47f0f50bc10bae845c094"
	-> (sha256 (sha256 (string-append "00" hash160)))
	"d61967f63c7dd183914a4ae452c9f6ad5d462ce3d277798075b107615c1a8a30"
	-> (define checksum (substring (sha256 (sha256 (string-append "00" hash160))) 0 8))
	-> checksum
	"d61967f6"
	-> (define address/hex (string-append "00" hash160 checksum))
	-> address/hex
	"00010966776006953d5567439e5e39f86a0d273beed61967f6"
	   
### Software ###

In this post, I'm using OpenSSL 1.0.1e, Racket 6.0.0.3, and running Debian
7.0.
