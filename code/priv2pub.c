#include <stdlib.h>
#include <stdio.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h> // for NID_secp256k1

#define PRIV_KEY_LEN 32
#define PUB_KEY_LEN 65

// calculates and returns the public key associated with the given private key
// - input private key and output public key are in hexadecimal
unsigned char *priv2pub( const unsigned char *priv_hex )
{
  EC_GROUP *ecgrp = EC_GROUP_new_by_curve_name( NID_secp256k1 );

  // convert priv key from hexadecimal to BIGNUM
  BIGNUM *priv_bn = BN_new();
  BN_hex2bn( &priv_bn, priv_hex );

  // compute pub key from priv key and group
  EC_POINT *pub = EC_POINT_new( ecgrp );
  EC_POINT_mul( ecgrp, pub, priv_bn, NULL, NULL, NULL );

  // convert pub_key from EC_POINT curve coordinate to hexadecimal
  unsigned char *ret = EC_POINT_point2hex( ecgrp, pub, POINT_CONVERSION_UNCOMPRESSED, NULL );

  EC_GROUP_free( ecgrp ); BN_free( priv_bn ); EC_POINT_free( pub );

  return ret;
}

int main( int argc, const unsigned char *argv[] )
{
  // compute pub key
  unsigned char *pub_hex = priv2pub( argv[1] );

  // print computed pub key
  for( size_t i = 0; i < PUB_KEY_LEN * 2; i++ ) {
    printf( "%c", pub_hex[i] );
  }
  printf( "\n" );

  free( pub_hex );

  return 0;
}
