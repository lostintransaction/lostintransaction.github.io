#lang racket ; not racket/base, to get 'so runtime-path option
(require ffi/unsafe racket/runtime-path)
(require (only-in file/sha1 bytes->hex-string))
(provide (all-defined-out))

;; cmd to compile priv2pub.c to .so shared lib:
;;   gcc -fPIC -lcrypto -std=c99 -shared -Wl,-soname,libpriv2pub.so.1 priv2pub.c -o libpriv2pub.so.1.0

(define COMPRESSED 2) ; POINT_CONVERSION_COMPRESSED
(define COMPRESSED-LEN 33)
(define UNCOMPRESSED 4) ; POINT_CONVERSION_UNCOMPRESSED
(define UNCOMPRESSED-LEN 65)

(define-runtime-path libpriv2pub-so '(so "libpriv2pub"))

(define libpriv2pub (ffi-lib libpriv2pub-so '("1.0")))

(define priv2pub_bytes
  (get-ffi-obj 'priv2pub_bytes libpriv2pub
    (_fun _string _int (_bytes o UNCOMPRESSED-LEN) 
          -> (_bytes o UNCOMPRESSED-LEN))))

;; this version leaks memory (ie must be manually freed)
;; (define priv2pub
;;   (get-ffi-obj 'priv2pub libpriv2pub
;;     (_fun _string _int -> _string)))

(define (priv-key->pub-key/compressed priv/hex)
  (bytes->hex-string 
    (subbytes (priv2pub_bytes priv/hex COMPRESSED) 0 COMPRESSED-LEN)))
(define (priv-key->pub-key priv/hex)
  (bytes->hex-string 
    (priv2pub_bytes priv/hex UNCOMPRESSED)))

(module+ main
  (define args (current-command-line-arguments))
  (define num-args (vector-length args))
  (cond
   [(zero? num-args)
    (printf "Please provide a private key input (in hex).\n")]
   [(= num-args 1)
    (define arg (vector-ref args 0))
    (printf "~a\n" (priv-key->pub-key arg))]
   [else (printf "Please only provide one input.\n")]))
      

(module+ test
  (require (prefix-in r: rackunit))
  (define-syntax-rule (check-hex-equal? x y)
    (r:check-equal? (string-downcase x) (string-downcase y)))
  (define priv-key1 
    "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725")
  (define pub-key1
    "0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6")
  (define priv-key2
    "4DD3D47E491C5D34F9540EBF3444E3D6675015A46B61AF37B4EB7F17DDDF4E61")
  (define pub-key2
    "0492EDC09A7311C2AB83EF3D133331D7B73117902BB391D9DAC3BE261547F571E171F16775DDA6D09A6AAF1F3F6E6AA3CFCD854DCAA6AED0FA7AF9A5ED9965E117")
  
  (check-hex-equal? (priv-key->pub-key priv-key1) pub-key1)
  (check-hex-equal? (priv-key->pub-key priv-key2) pub-key2))
