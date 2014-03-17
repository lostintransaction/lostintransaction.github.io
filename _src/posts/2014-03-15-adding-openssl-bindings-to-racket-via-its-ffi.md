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
module creates a path for Racket code to call into a specified C
library. Racket actually already has some bindings for OpenSSL
functions (but not the ones I want), so I'm going to cheat a little
and use the
[already-available `libcrypto` hook][plt:libcrypto]. Here's the exact
call to `ffi-lib`:

```racket
(define libcrypto
  (ffi-lib libcrypto-so '("" "1.0.1e" "1.0.0" "1.0" "0.9.8b" "0.9.8" "0.9.7")))
```

The first argument is the name of the C library and the second
argument is a list of acceptable versions.

[racket:ffilib]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=ffi-lib#%28def._%28%28lib._ffi%2Funsafe..rkt%29._ffi-lib%29%29 "Racket docs: ffi-lib"
[plt:libcrypto]: https://github.com/plt/racket/blob/8b4c5d3debbe41c90e37e5ffdc55fb8ab3635f92/racket/collects/openssl/libcrypto.rkt "Racket source: openssl/libcrypto.rkt"

Let's create a Racket binding for a specific C function, for example [`SHA256`][openssl:sha256]. Here's the header in C:

```C
unsigned char *SHA256( const unsigned char *d, size_t n, unsigned char *md );
```


To create the Racket binding, we use the
[`get-ffi-obj`][racket:getffiobj] Racket function. Here's the binding
for SHA-256 might look like:

```racket
(define sha256
  (get-ffi-obj
    'SHA256 libcrypto
	(_fun [input     : _bytes]
	      [input-len : _ulong = (bytes-length input)]
		  [output    : (_bytes o SHA256-DIGEST-LEN)]
		  -> _bytes
		  -> (make-sized-byte-string output SHA256-DIGEST-LEN))))
```

The first argument is the name of the C function and the second is the
library hook that we created with `ffi-lib`. The third argument is the
type, which specifies how to mediate between Racket and C values. The
function type is [`_fun`][racket:fun] and in this case the function
has three arguments (each one specified in brackets).

Examining the arguments:

1. The C first argument is an array of input bytes and we use `_bytes`
to indicate this in Racket.

2. The second argument specifies the length of the input byte
array. The `=` tells Racket how to calculate this argument
automatically. That means a caller of the Racket `sha256` wrapper
function can provide the input bytes without a separate length
argument.

3. The third argument is the output byte array. In Racket, the `o`
indicates a return pointer and the `SHA256-DIGEST-LEN` indicates the
expected number of output bytes.

[openssl:sha256]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/sha/sha.h;h=8a6bf4bbbb1dbef37869fc162ce1c2cacfebeb1d;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l155 "OpenSSL source: crypto/sha/sha.h"
[racket:getffiobj]: http://docs.racket-lang.org/foreign/Loading_Foreign_Libraries.html?q=get-ffi-obj#%28def._%28%28lib._ffi%2Funsafe..rkt%29._get-ffi-obj%29%29 "Racket docs: get-ffi-obj"
[racket:fun]: http://docs.racket-lang.org/foreign/foreign_procedures.html?q=_fun#%28form._%28%28lib._ffi%2Funsafe..rkt%29.__fun%29%29 "Racket docs: _fun"

TODO:
- Don't need id on some args (like input-len). Only need id if you want to refer to it later. Not sure I need `make-sized-byte-string` for output. I think (_bytes o SHA256-DIGEST-LEN) is suffiient.
- make these changes in crypto.rkt
