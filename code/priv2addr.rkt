#lang racket/base
(require "priv2pub.rkt" "crypto.rkt" "base58.rkt")
(provide (all-defined-out))

(define (prepend-version0 str) (string-append "00" str))

;; checksum is 1st 4 bytes (8 chars) of double sha256 hash of given hex string
(define (get-checksum hstr) 
  (substring (sha256/hex (sha256/hex hstr)) 0 8))

;; adds checksum to given hex string
(define (add-checksum hstr) 
  (string-append hstr (get-checksum hstr)))

(define priv-key->addr
  (compose hex-str->base58-str 
           add-checksum 
           prepend-version0
           ripemd160/hex
           sha256/hex
           priv2pub))

(module+ test
  (require rackunit)
  (define priv-key 
    "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725")
  (define addr "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  
  (check-equal? (priv-key->addr priv-key) addr))
