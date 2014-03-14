    Title: Deriving a Bitcoin Public Key From a Private Key
    Date: 2014-03-14T05:28:01
    Tags: public key, private key, elliptic curve, openssl

I've been wondering about the relationship between Bitcoin public and
private keys. I know they are [Elliptic Curve DSA (ECDSA)][wiki:ecdsa]
key pairs, and I've seen the [`Q = dG` explanation][so] on a few
sites, but they leave out some details. I wanted to experiment, so
this post describes how to derive a public key from a private key with
runnable C code.

[wiki:ecdsa]: http://en.wikipedia.org/wiki/Elliptic_Curve_DSA "Wikipedia: Elliptic Curve DSA"
[so]: http://stackoverflow.com/questions/12480776/how-do-i-obtain-the-public-key-from-an-ecdsa-private-key-in-openssl "Stack Overflow: Public Key from Private Key"

<!-- more -->

The [accepted Stack Overflow answer from the previous link][so2] says that in
the `Q = dG` equation, `Q` is the public key and `d` is the private
key, but does not explain `G`, the group parameter. Luckily, some
Googling quickly finds that Bitcoin uses the
[`secp256k1` ECDSA curve][wiki].

[so2]: http://stackoverflow.com/a/12482384/951881 "Stack Overflow: Public Key from Private Key Answer"
[wiki]: https://en.bitcoin.it/wiki/Secp256k1 "secp256k1 Bitcoin wiki entry"

Next, I looked at the [OpenSSL][openssl] `libcrypto` library, in the
[function mentioned in the Stack Overflow post, `EC_KEY_generate_key`][ec_key]. Here's
the line that performs the multiplication:

```c
EC_POINT_mul(eckey->group, pub_key, priv_key, NULL, NULL, ctx);
```

In my case, I'm supplying `priv_key` and `pub_key` is the output
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

Putting everything together, here's what I came up with to compute a
public key from a private key (disclaimer: the code has no
error-checking and is obviously not production-quality):

```c
#include <stdlib.h>
#include <stdio.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h> // for NID_secp256k1

#define PRIV_KEY_LEN 32
#define PUB_KEY_LEN 65

// reads 2 hex chars at a time from in and writes as a byte to out
void hex2bytes( const unsigned char *in, size_t len, unsigned char *out )
{
  for( size_t i = 0; i < len; i++, in += 2 ) {
    sscanf( in, "%2hhx", out + i );
  }
}
// prints the given char array
void print_chars( const unsigned char *in, size_t len )
{
  for( size_t i = 0; i < len; i++ ) {
    printf( "%c", in[i] );
  }
  printf( "\n" );
}
// calculates and returns the public key associated with the given private key
// input private key is in hex
unsigned char *priv2pub( const unsigned char *priv_hex, size_t len )
{
  const EC_GROUP *ecgroup = EC_GROUP_new_by_curve_name( NID_secp256k1 );

  // convert priv_key from hex to bytes to BIGNUM
  unsigned char privkey_bytes[PRIV_KEY_LEN];
  hex2bytes( priv_hex, PRIV_KEY_LEN, privkey_bytes );
  const BIGNUM *privkey_bn = BN_bin2bn( privkey_bytes, len, NULL );
  
  // allocate pub_key
  EC_POINT *pub_key = EC_POINT_new( ecgroup );
  
  // compute pub_key
  EC_POINT_mul( ecgroup, pub_key, privkey_bn, NULL, NULL, NULL );
										
  // convert pub_key from EC_POINT curve coordinate to hex
  return
    EC_POINT_point2hex( ecgroup, pub_key, POINT_CONVERSION_UNCOMPRESSED, NULL );
}
											  
int main( int argc, const unsigned char *argv[] )
{
  print_chars( priv2pub( argv[1], PRIV_KEY_LEN ), PUB_KEY_LEN * 2 );
  
  return 0;
}
```

Bitcoin private keys are 32 bytes and public keys are 65 bytes. The
input and output are in hexadecimal so I created a `hex2bytes` helper
function. I had to then convert the private key again, from bytes to
`BIGNUM`, which is OpenSSL's number representation for arbitrary
precision arithmetic. Finally, I use another helper function,
`print_chars`, to print the final result.

To test, I borrowed a sample public/private key pair from
[this Bitcoin wiki article][wiki:address]. The private key from the
article is
`18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725` and
the public key is
`0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`. Let's
see if our program can recover this public key from the private
key. (I save the code above to a file `blog.c`.)

    $ gcc -lcrypto -std=c99 blog.c
    $ ./a.out 18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725
	0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6

Success!

[wiki:address]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin wiki: technical explanation of addresses"

Let's do another one. I generated a private key with [bitaddress.org](https://www.bitaddress.org), `5JQZaZrYCbJ1Kb96vFBMEefrQGuNfHSqbHbviC3URUNGJ27frFe`, but it's in [Base58Check encoding][bwiki:base58] and not hex. So I went to the "Wallet Details" tab, entered the base58 key, and [bitaddress.org](https://www.bitaddress.org) reports that the private key in hex is `4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61` and public key is `0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117`. Let's check with our code:

    $ ./a.out 4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61
	0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117

[bwiki:base58]: https://en.bitcoin.it/wiki/Base58Check_encoding "Bitcoin wiki: Base58Check encoding"

Hurrah!

### Software ###

In this post, I'm using OpenSSL 1.0.1e, gcc 4.7.2, and running Debian
7.0. I had to also install the `libssl-dev` package to get the proper
header files.
