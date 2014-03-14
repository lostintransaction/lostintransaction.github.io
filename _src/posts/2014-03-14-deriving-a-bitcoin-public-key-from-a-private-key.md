    Title: Deriving a Bitcoin Public Key From a Private Key
    Date: 2014-03-14T05:28:01
    Tags: public key, private key, elliptic curve

I've been wondering about the relationship between Bitcoin public and
private keys. I've seen the [`Q = dG` explanation][so] but it leaves
out a few too many details for my tastes. This post describes how to
derive a public key from a private key with conrete, runnable C code.

[so]: http://stackoverflow.com/questions/12480776/how-do-i-obtain-the-public-key-from-an-ecdsa-private-key-in-openssl "Stack Overflow: Public Key from Private Key"

<!-- more -->

The Stack Overflow post says that in the `Q = dG` equation, `Q` is the
public key and `d` is the private key, but does not explain `G`, the
group parameter. Luckily, some Googling quickly finds that Bitcoin
uses the [`secp256k1` ECDSA curve][wiki].

[wiki]: https://en.bitcoin.it/wiki/Secp256k1 "secp256k1 Bitcoin wiki entry"

Next, I started by looking at the OpenSSL `libcrypto` library, at the
[function mentioned in the Stack Overflow post][ec_key],
`EC_KEY_generate_key`. Here's the line that performs the
multiplication again:

```c
EC_POINT_mul(eckey->group, pub_key, priv_key, NULL, NULL, ctx);
```

The `priv_key` is known and the `pub_key` is an output parameter, so
we just need to pass in the appropriate group as the first
parameter. OpenSSL has
[already defined the `secp256k1` curve][obj_mac] (in
`crypto/objects/obj_mac.h`), so it's just a matter of finding the
right calls. In this case, we want [`EC_GROUP_new_by_curve_name`][ec_curve].

[ec_key]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_key.c;h=7fa247593d91b45347704e62e184e1138fc8bd01;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l236 "crypto/ec/ec_key.c"
[obj_mac]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/objects/obj_mac.h;h=b5ea7cdab4f84b90280f0a3aae1478a8d715c7a7;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l385 "crypto/objects/obj_mac.h"
[ec_curve]: http://git.openssl.org/gitweb/?p=openssl.git;a=blob;f=crypto/ec/ec_curve.c;h=c72fb2697ca2823a4aac36b027012bed6c457288;hb=46ebd9e3bb623d3c15ef2203038956f3f7213620#l2057 "crypco/ec/ec_curve.c"

Here's what my public-from-private-key function looks like:

```c
#include <stdlib.h>
#include <stdio.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h> // for NID_secp256k1

#define PRIV_KEY_LENGTH 32
#define PUB_KEY_LENGTH 65

void hex2bytes(const unsigned char *in, size_t len, unsigned char *out) {
  for(size_t i=0; i<len; i++,in+=2) sscanf(in, "%2hhx", out+i);
}

void print_chars(unsigned char *in, size_t len) {
  for(size_t i=0; i<len; i++) printf("%c",in[i]); printf("\n");
}
		
unsigned char *priv2pub(const unsigned char *priv_hex, size_t len) {
  const EC_GROUP *ecgroup = EC_GROUP_new_by_curve_name(NID_secp256k1);
  unsigned char privkey_bytes[PRIV_KEY_LENGTH];
  hex2bytes(priv_hex, PRIV_KEY_LENGTH, privkey_bytes);
  const BIGNUM *privkey_bn = BN_bin2bn(privkey_bytes, len, NULL);
  EC_POINT *pub_key = EC_POINT_new(ecgroup);
  EC_POINT_mul(ecgroup, pub_key, privkey_bn, NULL, NULL, NULL);
  return EC_POINT_point2hex(ecgroup, pub_key, POINT_CONVERSION_UNCOMPRESSED, NULL);
}

int main() {
  const unsigned char privkey_hex[] = "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725";
  print_chars(priv2pub(privkey_hex, PRIV_KEY_LENGTH), PUB_KEY_LENGTH*2);
  return 0;
}
```

I borrowed a sample public/private key pair from
[this Bitcoin wiki article][wiki:address]. You can see the private
key,
`18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725`,
hardcoded in the program. Bitcoin private keys are 32 bytes and public
keys are 65 bytes. I wanted the input and output to be hexadecimal, so
I needed a `hex2bytes` helper function. I had to then convert the
private key again, from bytes to `BIGNUM`, which is the type OpenSSL
uses for arbitrary precision arithmetic. Finally, I use another helper
function, `print_chars`, to print the final result.


The public key from the article is `0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6`. Let's see if our program can recover this public key from the private key. (I save the code above to a file `blog.c`.)

    $ gcc -lcrypto -std=c99 blog.c
    $ ./a.out
    0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6

Success!

[wiki:address]: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses "Bitcoin wiki entry about addresses"

### Software ###

In this post, I'm using OpenSSL 1.0.1e, gcc 4.7.2, and running Debian
7.0. I had to also install the `libssl-dev` package to get the proper
header files.
