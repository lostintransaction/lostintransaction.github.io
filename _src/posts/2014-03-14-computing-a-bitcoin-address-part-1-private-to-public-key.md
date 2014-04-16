    Title: Computing a Bitcoin Address, Part 1: Private to Public Key
    Date: 2014-03-14T05:28:01
    Tags: public key, private key, elliptic curve, OpenSSL, C, Racket, FFI

I've been wondering how Bitcoin addresses are generated. This post and
the ones following will explore, step by step, how to transform a
Bitcoin private key to a public address.

I know that Bitcoin public and private keys are
[Elliptic Curve DSA (ECDSA)][wiki:ecdsa] key pairs, and I've seen the
[`Q = dG` explanation][so] on a few sites, but they leave out some
details. I want to experiment for myself, so this post describes how
to derive a public key from a private key with runnable code.

[wiki:ecdsa]: http://en.wikipedia.org/wiki/Elliptic_Curve_DSA "Wikipedia: Elliptic Curve DSA"
[so]: http://stackoverflow.com/questions/12480776/how-do-i-obtain-the-public-key-from-an-ecdsa-private-key-in-openssl "Stack Overflow: Public Key from Private Key"

<!-- more -->

-------------------------------------------------------------------------------

This is the first post in a four-part series. Here are the rest of the
articles in the series:
* [Part 2: Public Key to (Hex) Address](http://www.lostintransaction.com/blog/2014/03/15/computing-a-bitcoin-address-part-2-public-key-to-hex-address/)
* [Part 3: Base58Check Encoding](http://www.lostintransaction.com/blog/2014/03/18/computing-a-bitcoin-address-part-3-base58check-encoding/)
* [Part 4: Wallet Import Format (WIF)](http://www.lostintransaction.com/blog/2014/04/09/computing-a-bitcoin-address-part-4-wallet-import-format-wif/)

-------------------------------------------------------------------------------

The [accepted Stack Overflow answer from the previous link][so2] says that in
the `Q = dG` equation, `Q` is the public key and `d` is the private
key, but does not explain `G`, the group parameter. Luckily, some
Googling quickly finds that Bitcoin uses the
[`secp256k1` ECDSA curve][bwiki:secp].

[so2]: http://stackoverflow.com/a/12482384/951881 "Stack Overflow: Public Key from Private Key Answer"
[bwiki:secp]: https://en.bitcoin.it/wiki/Secp256k1 "secp256k1 Bitcoin wiki entry"

Next, I looked at the [OpenSSL][openssl] `libcrypto` C library, in
[`EC_KEY_generate_key` (the function mentioned in the Stack Overflow post)][ec_key]. Here's
the line that performs the multiplication:

```c
EC_POINT_mul(eckey->group, pub_key, priv_key, NULL, NULL, ctx);
```

In this case, I'm supplying `priv_key`, and `pub_key` is the output
parameter, so I just need the appropriate group for the first
parameter. OpenSSL has
[already defined the `secp256k1` curve][obj_mac], so it's just a
matter of getting the right data representation. Here is the
[header for `EC_POINT_mul`][openssl:ech] from the OpenSSL library:

```c
/** Computes r = generator * n + q * m
 *  \param  group  underlying EC_GROUP object
 *  \param  r      EC_POINT object for the result
 *  \param  n      BIGNUM with the multiplier for the group generator (optional)
 *  \param  q      EC_POINT object with the first factor of the second summand
 *  \param  m      BIGNUM with the second factor of the second summand
 *  \param  ctx    BN_CTX object (optional)
 *  \return 1 on success and 0 if an error occured
 */
int EC_POINT_mul(const EC_GROUP *group, EC_POINT *r, const BIGNUM *n, const EC_POINT *q, const BIGNUM *m, BN_CTX *ctx);
```

Looks like we need an `EC_GROUP`. To create one we call
[`EC_GROUP_new_by_curve_name`][ec_curve].

[openssl]: https://www.openssl.org/ "OpenSSL"
[ec_key]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_key.c;h=7fa247593d91b45347704e62e184e1138fc8bd01;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l236 "crypto/ec/ec_key.c"
[openssl:ech]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec.h;h=dfe8710d330954bb1762a5fe13d655ac7a5f01be;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l643 "crypto/ec/ec.h"
[obj_mac]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/objects/obj_mac.h;h=b5ea7cdab4f84b90280f0a3aae1478a8d715c7a7;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l385 "crypto/objects/obj_mac.h"
[ec_curve]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_curve.c;h=c72fb2697ca2823a4aac36b027012bed6c457288;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l2057 "crypco/ec/ec_curve.c"

Putting everything together, here's a function `priv2pub` that
computes a public key from a private key (disclaimer: the
code has no error-checking so don't use this in production):

```c
// calculates and returns the public key associated with the given private key
// - input private key and output public key are in hexadecimal
// form = POINT_CONVERSION_[UNCOMPRESSED|COMPRESSED|HYBRID]
unsigned char *priv2pub( const unsigned char *priv_hex,
                         point_conversion_form_t form )
{
  // create group
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );
  
  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );
  
  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );
							  
  // convert pub_key from elliptic curve coordinate to hexadecimal
  unsigned char *ret = EC_POINT_point2hex( ecgrp, pub, form, NULL );
	
  EC_GROUP_free( ecgrp ); BN_free( priv_bn ); EC_POINT_free( pub );
  
  return ret;
}
```

The function assumes that the input private key is in hex, and
returned public key is in hex as well. I had to first convert the
private key to `BIGNUM`, which is OpenSSL's number representation for
arbitrary precision arithmetic. The computed public key is an OpenSSL
`EC_POINT` data structure, which represents a curve coordinate. The
curve coordinate is converted back to hex using
`EC_POINT_point2hex`. [Public keys can either be compressed or uncompressed][bwiki:ecdsa],
and the format of the output of `priv2pub` depends on the `form` input
parameter, [which can be one of three values][point_conversion].

[bwiki:ecdsa]: https://en.bitcoin.it/wiki/Elliptic_Curve_Digital_Signature_Algorithm "Bitcoin Wiki: Elliptic Curve Digital Signature Algorithm"
[point_conversion]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec.h;h=dfe8710d330954bb1762a5fe13d655ac7a5f01be;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l104 "crypto/ec/ec.h"

To test this function, I found a sample public/private key pair from
[this Bitcoin wiki article][bwiki:address]. The private key from the
article is
`18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725` and
the public key is
`0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`. The
public key begins with `0x04` [so we know it's in uncompressed form][sec]
and is 65 bytes long (see ANSI X9.62 for more details).

I used the following main function to test if `priv2pub` can compute
the public key with the private key from the example:

[sec]: http://www.secg.org/collateral/sec1.pdf "SEC: Elliptic Curve Cryptography"

```c
int main( int argc, const unsigned char *argv[] )
{
  // get priv key from cmd line and compute pub key
  unsigned char *pub_hex = priv2pub( argv[1], POINT_CONVERSION_UNCOMPRESSED );
  
  printf( "%s\n", pub_hex );
	
  free( pub_hex );
  
  return 0;
}
```

I save the code above to a file `priv2pub.c`:

    $ gcc -lcrypto -std=c99 priv2pub.c -o priv2pub
    $ ./priv2pub 18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725
	0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6

Success!

[bwiki:address]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin wiki: technical explanation of addresses"

Let's try another example. I generated a private key with [bitaddress.org](https://www.bitaddress.org), `5JQZaZrYCbJ1Kb96vFBMEefrQGuNfHSqbHbviC3URUNGJ27frFe`, but it's in [Base58Check encoding][bwiki:base58] and not hex. We'll deal with Base58 encoding later so for now I went to the "Wallet Details" tab at [bitaddress.org](https://www.bitaddress.org), entered the base58 key, and got back that the private key in hex is `4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61` and public key is `0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117`. Let's check what our code says:

    $ ./priv2pub 4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61
	0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117

[bwiki:base58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Bitcoin wiki: Base58Check encoding"

Hurrah!

### A Racket Version

I'm using [Racket](http://racket-lang.org), a modern LISP dialect, to
experiment with Bitcoin so I want a Racket version of my conversion
function as well. Fortunately, Racket has an [FFI][racketffi] that
enables Racket code to call C functions directly.

[racketffi]: http://docs.racket-lang.org/foreign/index.html "Racket FFI"

First I create a slightly different version of my C function:

```c
// calculates and returns the public key associated with the given private key
// - input private key is in hexadecimal
// - output public key is in raw bytes
// form = POINT_CONVERSION_[UNCOMPRESSED|COMPRESSED|HYBRID]
unsigned char *priv2pub_bytes( const unsigned char *priv_hex,
                               point_conversion_form_t form,
                               unsigned char *ret )
{
  // create group
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );
  
  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );
  
  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );
  
  // convert pub key from elliptic curve coordinate to bytes
  //  (first call gets the appropriate length to use)
  size_t len = EC_POINT_point2oct( ecgrp, pub, form, NULL, 0, NULL );
  EC_POINT_point2oct( ecgrp, pub, form, ret, len, NULL );
		
  EC_GROUP_free( ecgrp ); BN_free( priv_bn ); EC_POINT_free( pub );
  
  return ret;
}
```

The difference is an extra parameter and the representation of the
public key output. This new function uses `EC_POINT_point2oct` to
return a byte string instead of a hex string. The problem is that the
hex conversion function, `EC_POINT_point2hex`, allocates, but I don't
want to manually manage memory in Racket. Because `priv2pub_bytes`
consumes an additional buffer parameter, Racket can allocate a buffer
controlled by the GC prior to calling the function, and then pass in
this allocated buffer.

Next I use Racket's FFI to create a Racket wrapper function for the
`priv2pub_bytes` C function. The FFI requires a library file, so I
compile the `.c` file to a `.so` library.

    $ gcc -lcrypto -std=c99 -fPIC -shared -Wl,-soname,libpriv2pub.so.1 priv2pub.c -o libpriv2pub.so.1.0
	
This creates a dynamic library file named `libpriv2pub.so.1.0`.

To create a Racket value for this library, we use the Racket `ffi-lib`
function:

```racket
(define-runtime-path libpriv2pub-so '(so "libpriv2pub"))

(define libpriv2pub (ffi-lib libpriv2pub-so '("1.0")))
```

The first argument to `ffi-lib` is the path of the library and the
second argument specifies a list of acceptable version numbers.

Once we have a hook into the C library, we can create Racket wrappers
for individual functions in the library. We use the Racket
`get-ffi-obj` function to do this:

```racket
(define UNCOMPRESSED-LEN 65)
(define priv2pub_bytes
  (get-ffi-obj 'priv2pub_bytes libpriv2pub
    (_fun _string _int (_bytes o UNCOMPRESSED-LEN)
          -> (_bytes o UNCOMPRESSED-LEN))))
```

This creates a Racket function `priv2pub_bytes` where the first
argument is a (Racket) string, the second is an int indicating whether
the output should be in compressed or uncompressed form, and the third
is the output buffer. A pointer to the output buffer is also returned
by the function. We make the size the output buffer equal to the
uncompressed form since that is the maximum size.

Let's make things easier to use with a couple more functions:

```racket
(define COMPRESSED 2) ; POINT_CONVERSION_COMPRESSED
(define UNCOMPRESSED 4) ; POINT_CONVERSION_UNCOMPRESSED
(define COMPRESSED-LEN 33)
(define (priv-key->pub-key/compressed priv/hex)
  (bytes->hex-string 
    (subbytes (priv2pub_bytes priv/hex COMPRESSED) 0 COMPRESSED-LEN)))
(define (priv-key->pub-key priv/hex)
  (bytes->hex-string 
    (priv2pub_bytes priv/hex UNCOMPRESSED)))
```

`priv-key->pub-key` consumes a private key in hex and returns an
uncompressed public key, also in hex. `priv-key->pub-key/compressed`
is similar except it returns a compressed public key (note that this
function extracts only the first 33 bytes of the output buffer).

Testing our examples again, with
[the Racket (extended) REPL][racket:xrepl], we see that our Racket
functions produce the same results:

[racket:xrepl]: http://docs.racket-lang.org/xrepl/index.html "XREPL"

    $ racket
    Welcome to Racket v6.0.0.3.
    -> (require "priv2pub.rkt")
    -> (priv-key->pub-key "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725")
    "0450863ad64a87ae8a2fe83c1af1a8403cb53f53e486d8511dad8a04887e5b23522cd470243453a299fa9e77237716103abc11a1df38855ed6f2ee187e9c582ba6"
    -> (priv-key->pub-key "4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61")
    "0492edc09a7311c2ab83ef3d133331d7b73117902bb391d9dac3be261547f571e171f16775dda6d09a6aaf1f3f6e6aa3cfcd854dcaa6aed0fa7af9a5ed9965e117"

### Software ###

The C code from this post
[is available here](http://www.lostintransaction.com/code/priv2pub.c)
and the Racket code
[is available here](http://www.lostintransaction.com/code/priv2pub.rkt). In
this post, I'm using OpenSSL 1.0.1e and gcc 4.7.2, running in Debian
7.0. I had to install the `libssl-dev` package to get the proper
header files.
