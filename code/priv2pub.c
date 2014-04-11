#include <stdlib.h>
#include <stdio.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h> // for NID_secp256k1

#define PRIV_KEY_LEN 32
#define PUB_KEY_COMPRESSED_LEN 33
#define PUB_KEY_UNCOMPRESSED_LEN 65

// calculates and returns the public key associated with the given private key
// - input private key is in hex
// - output public key is EC_POINT
// form = POINT_CONVERSION_UNCOMPRESSED 
//     or POINT_CONVERSION_COMPRESSED
//     or POINT_CONVERSION_HYBRID
EC_POINT *priv2pub_ecpoint( const unsigned char *priv_hex, 
                            point_conversion_form_t form )
{
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );

  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );

  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );

  EC_GROUP_free( ecgrp ); BN_free( priv_bn );

  return pub;
}

// calculates and returns the public key associated with the given private key
// - input private key in hex
// - output public key is in bytes
// - function caller manages memory alloc/dealloc of ret
// form = POINT_CONVERSION_UNCOMPRESSED 
//     or POINT_CONVERSION_COMPRESSED
//     or POINT_CONVERSION_HYBRID
/* unsigned char *priv2pub_bytes( const unsigned char *priv_hex,  */
/*                                point_conversion_form_t form,  */
/* 			       size_t len, unsigned char *ret ) */
/* { */
/*   EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 ); */

/*   EC_POINT *pub = priv2pub_ecpoint( priv_hex, form ); */

/*   /\* // first call to point2oct gets length *\/ */
/*   /\* size_t len = EC_POINT_point2oct( ecgrp, pub, form, NULL, 0, NULL ); *\/ */
  
/*   EC_POINT_point2oct( ecgrp, pub, form, ret, len, NULL ); */
  
/*   EC_GROUP_free( ecgrp ); EC_POINT_free( pub ); */

/*   return ret; */
/* } */


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

// calculates and returns the public key associated with the given private key
// - input private key and output public key are in hexadecimal
// - output is null-terminated string
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

int main( int argc, const unsigned char *argv[] )
{
  // compute pub key
  unsigned char *pub_hex = priv2pub( argv[1], POINT_CONVERSION_UNCOMPRESSED );

  // print computed pub key
  /* for( size_t i = 0; i < PUB_KEY_UNCOMPRESSED_LEN * 2; i++ ) { */
  /*   printf( "%c", pub_hex[i] ); */
  /* } */
  /* printf( "\n" ); */

  printf( "%s\n", pub_hex );

  free( pub_hex );

  return 0;
}

// testcase : 
// $./priv2pub 18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725
// 0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6
