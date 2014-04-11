#lang racket/base
(require ffi/unsafe openssl/libcrypto)
(require (only-in openssl/sha1 hex-string->bytes
                               bytes->hex-string))
(provide (all-defined-out))

(define SHA256-DIGEST-LEN 32) ; bytes
(define RIPEMD160-DIGEST-LEN 20) ; bytes

; from crypto/sha/sha.h: 
;  unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);
(define sha256
  (get-ffi-obj 'SHA256 libcrypto
    (_fun [input     : _bytes]
          [input-len : _ulong = (bytes-length input)]
          [output    : (_bytes o SHA256-DIGEST-LEN)]
          -> (_bytes o SHA256-DIGEST-LEN))))

(define (sha256/hex input)
  (bytes->hex-string (sha256 (hex-string->bytes input))))

; from crypto/ripemd/ripemd.h
;  unsigned char *RIPEMD160(const unsigned char *d, size_t n, unsigned char *md);
(define ripemd160
  (get-ffi-obj 
    'RIPEMD160 libcrypto
    (_fun [input     : _bytes]
          [input-len : _ulong = (bytes-length input)]
          [output    : (_bytes o RIPEMD160-DIGEST-LEN)]
          -> (_bytes o RIPEMD160-DIGEST-LEN))))

(define (ripemd160/hex input)
  (bytes->hex-string (ripemd160 (hex-string->bytes input))))

(module+ test
  (require (prefix-in r: rackunit))
  (define-syntax-rule (check-hex-equal? x y) 
    (r:check-equal? (string-downcase x) (string-downcase y)))
  ; example from: 
  ; https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
  (define pub-key
    "0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6")
  (define pub-key-sha256
    "600FFE422B4E00731A59557A5CCA46CC183944191006324A447BDB2D98D4B408")
  (define hash160 "010966776006953D5567439E5E39F86A0D273BEE")
  (define hash160/extended "00010966776006953D5567439E5E39F86A0D273BEE")
  (define hash160/ext-sha256 
    "445C7A8007A93D8733188288BB320A8FE2DEBD2AE1B47F0F50BC10BAE845C094")
  (define hash160/ext-sha256x2
    "D61967F63C7DD183914A4AE452C9F6AD5D462CE3D277798075B107615C1A8A30")
  (define checksum "D61967F6")
  (define address/hex "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
  
  (check-hex-equal? (sha256/hex pub-key) 
                    pub-key-sha256)
  (check-hex-equal? (ripemd160/hex (sha256/hex pub-key))
                    hash160)
  (check-hex-equal? (string-append "00" (ripemd160/hex (sha256/hex pub-key)))
                    hash160/extended)
  (check-hex-equal? 
    (sha256/hex (string-append "00" (ripemd160/hex (sha256/hex pub-key))))
    hash160/ext-sha256)
  (check-hex-equal? 
    (sha256/hex 
      (sha256/hex 
        (string-append "00" (ripemd160/hex (sha256/hex pub-key)))))
    hash160/ext-sha256x2)
  (check-hex-equal?
    (substring 
      (sha256/hex 
        (sha256/hex 
          (string-append "00" (ripemd160/hex (sha256/hex pub-key))))) 0 8)
    checksum)
  (check-hex-equal?
    (string-append
      (string-append "00" (ripemd160/hex (sha256/hex pub-key))) 
      (substring 
        (sha256/hex 
          (sha256/hex 
            (string-append "00" (ripemd160/hex (sha256/hex pub-key))))) 
        0 8))
    address/hex))
