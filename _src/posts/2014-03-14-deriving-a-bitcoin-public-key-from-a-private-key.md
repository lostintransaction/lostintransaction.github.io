    Title: Deriving a Bitcoin Public Key From a Private Key
    Date: 2014-03-14T05:28:01
    Tags: public key, private key, elliptic curve, OpenSSL, C, Racket, FFI

I've been wondering about the relationship between Bitcoin private
keys, public keys, and addresses. This post and the ones following
will explore the steps needed to go from a Bitcoin private key to a
public address. This first post explores how to derive a Bitcoin
public key from a private key.

<!-- more -->

I know that Bitcoin public and private keys are
[Elliptic Curve DSA (ECDSA)][wiki:ecdsa] key pairs, and I've seen the
[`Q = dG` explanation][so] on a few sites, but they leave out some
details. I want to experiment for myself, so this post describes how
to derive a public key from a private key with runnable C code.

[wiki:ecdsa]: http://en.wikipedia.org/wiki/Elliptic_Curve_DSA "Wikipedia: Elliptic Curve DSA"
[so]: http://stackoverflow.com/questions/12480776/how-do-i-obtain-the-public-key-from-an-ecdsa-private-key-in-openssl "Stack Overflow: Public Key from Private Key"


The [accepted Stack Overflow answer from the previous link][so2] says that in
the `Q = dG` equation, `Q` is the public key and `d` is the private
key, but does not explain `G`, the group parameter. Luckily, some
Googling quickly finds that Bitcoin uses the
[`secp256k1` ECDSA curve][bwiki:secp].

[so2]: http://stackoverflow.com/a/12482384/951881 "Stack Overflow: Public Key from Private Key Answer"
[bwiki:secp]: https://en.bitcoin.it/wiki/Secp256k1 "secp256k1 Bitcoin wiki entry"

Next, I looked at the [OpenSSL][openssl] `libcrypto` library, in the
[function mentioned in the Stack Overflow post, `EC_KEY_generate_key`][ec_key]. Here's
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

Looks like we need an `EC_GROUP` and to create one we can use
[`EC_GROUP_new_by_curve_name`][ec_curve].

[openssl]: https://www.openssl.org/ "OpenSSL"
[ec_key]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_key.c;h=7fa247593d91b45347704e62e184e1138fc8bd01;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l236 "crypto/ec/ec_key.c"
[openssl:ech]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec.h;h=dfe8710d330954bb1762a5fe13d655ac7a5f01be;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l643 "crypto/ec/ec.h"
[obj_mac]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/objects/obj_mac.h;h=b5ea7cdab4f84b90280f0a3aae1478a8d715c7a7;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l385 "crypto/objects/obj_mac.h"
[ec_curve]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_curve.c;h=c72fb2697ca2823a4aac36b027012bed6c457288;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l2057 "crypco/ec/ec_curve.c"

Putting everything together, I came up with a function `priv2pub` to compute a
public key from a private key (disclaimer: the code has no
error-checking so don't use this in production):

```c
// calculates and returns the public key associated with the given private key
// - input private key and output public key are in hexadecimal
// form = POINT_CONVERSION_UNCOMPRESSED
//     or POINT_CONVERSION_COMPRESSED
//     or POINT_CONVERSION_HYBRID
unsigned char *priv2pub( const unsigned char *priv_hex,
                         point_conversion_form_t form )
{
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );
  
  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );
  
  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );
							  
  // convert pub_key from EC_POINT curve coordinate to hexadecimal
  unsigned char *ret = EC_POINT_point2hex( ecgrp, pub, form, NULL );
	
  EC_GROUP_free( ecgrp ); BN_free( priv_bn ); EC_POINT_free( pub );
  
  return ret;
}
```

The function assumes that the input private key is in hex, and
returned public key is in hex as well. I had to first convert the
private key to `BIGNUM`, which is OpenSSL's number representation for
arbitrary precision arithmetic. The computed public key is a curve
coordinate in OpenSSL's `EC_POINT` representation. I then convert back
to hex using
`EC_POINT_point2hex`. [Public keys can either be compressed or uncompressed][bwiki:ecdsa],
and the format of the output of `priv2pub` depends on the `form`
parameter, [which can be one of three values][point_conversion].

[bwiki:ecdsa]: https://en.bitcoin.it/wiki/Elliptic_Curve_Digital_Signature_Algorithm "Bitcoin Wiki: Elliptic Curve Digital Signature Algorithm"
[point_conversion]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec.h;h=dfe8710d330954bb1762a5fe13d655ac7a5f01be;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l104 "crypto/ec/ec.h"

To test, I found a sample public/private key pair from
[this Bitcoin wiki article][bwiki:address]. The private key from the
article is
`18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725` and
the public key is
`0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`. The public key is uncompressed here because it begins with a `0x04` and is 65 bytes long
(see the ANSI X9.62 standard).

Let's see if our program can recover this public key from the private
key. I used the following `main` function.

```
#define PUB_KEY_UNCOMPRESSED_LEN 65

int main( int argc, const unsigned char *argv[] )
{
  // compute pub key
  unsigned char *pub_hex = priv2pub( argv[1], POINT_CONVERSION_UNCOMPRESSED );
  
  // print computed pub key
  for( size_t i = 0; i < PUB_KEY_UNCOMPRESSED_LEN * 2; i++ ) {
    printf( "%c", pub_hex[i] );
  }
  printf( "\n" );
  
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

Let's do another one. I generated a private key with [bitaddress.org](https://www.bitaddress.org), `5JQZaZrYCbJ1Kb96vFBMEefrQGuNfHSqbHbviC3URUNGJ27frFe`, but it's in [Base58Check encoding][bwiki:base58] and not hex. So I went to the "Wallet Details" tab, entered the base58 key, and [bitaddress.org](https://www.bitaddress.org) reports that the private key in hex is `4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61` and public key is `0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117`. Let's check with our code:

    $ ./priv2pub 4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61
	0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117

[bwiki:base58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Bitcoin wiki: Base58Check encoding"

Hurrah!

### A Racket Version

I'm using [Racket](http://racket-lang.org), a modern LIST dialect, to
experiment with Bitcoin so I want a Racket version of my conversion
function as well. Fortunately, Racket has an [FFI][racketffi] that
enables Racket code to call C functions directly.

[racketffi]: http://docs.racket-lang.org/foreign/index.html "Racket FFI"

First I create a slightly different version of my C function:

```racket
// calculates and returns the public key associated with the given private key
// - input private key is in hexadecimal
// - output public key is in raw bytes
// form = POINT_CONVERSION_[UNCOMPRESSED|COMPRESSED|HYBRID]
// - len is number of bytes in output buffer, 33 for compressed, 65 otherwise
unsigned char *priv2pub_bytes( const unsigned char *priv_hex,
                               point_conversion_form_t form,
							   size_t len, unsigned char *ret )
{
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );
  
  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );
  
  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );
  
  // convert pub_key from EC_POINT curve coordinate to hexadecimal
  EC_POINT_point2oct( ecgrp, pub, form, ret, len, NULL );
  
  EC_GROUP_free( ecgrp ); BN_free( priv_bn ); EC_POINT_free( pub );
  
  return ret;
}
```

Uses `EC_POINT_point2oct` to return a byte string instead of a hex
string. I need a different function because the function I used earlier,
`EC_POINT_point2hex`, allocates, but I won't have the opportunity to
free in Racket. With the new `priv2pub_bytes` function, Racket
allocates a buffer, controlled by the GC, prior to calling the
function, and then passes in the allocated buffer.

To create a Racket wrapper for the `priv2pub_bytes` C function, I
first need to compile the C code to a `.so` file.

    $ gcc -lcrypto -std=c99 -fPIC -shared -Wl,-soname,libpriv2pub.so.1 -o libpriv2pub.so.1.0 priv2pub.c
	
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
for the library's functions. We use the Racket `get-ffi-obj` function
to do this:

```racket
(define priv2pub_bytes
  (get-ffi-obj 'priv2pub_bytes libpriv2pub
    (_fun _string _int [len : _int] (_bytes o len)
          -> (_bytes o len))))
```

This creates a wrapper function `priv2pub_bytes` in Racket where the
first argument is a (Racket) string, the second is an int (indicating
either compressed or uncompressed), the third is the length of the
output buffer and the fourth is the output buffer. A pointer to the
output buffer is also returned by the function.

Let's make this function easier to use with a couple more wrappers:

```racket
(define COMPRESSED 2) ; POINT_CONVERSION_COMPRESSED
(define COMPRESSED-LEN 33)
(define UNCOMPRESSED 4) ; POINT_CONVERSION_UNCOMPRESSED
(define UNCOMPRESSED-LEN 65)

(define (priv-key->pub-key/compressed priv/hex)
  (bytes->hex-string (priv2pub_bytes priv/hex COMPRESSED COMPRESSED-LEN)))
(define (priv-key->pub-key priv/hex)
  (bytes->hex-string (priv2pub_bytes priv/hex UNCOMPRESSED UNCOMPRESSED-LEN)))
```

We can now test our examples again:

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
