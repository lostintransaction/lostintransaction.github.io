#lang racket/base
(require "priv2pub.rkt" "crypto.rkt" "base58.rkt")
(provide (all-defined-out))

;; priv-key->addr fns ---------------------------------------------------------
(define (hash160/hex hstr) (ripemd160/hex (sha256/hex hstr)))
(define (add-version0 str) (string-append "00" str))

;; checksum is 1st 4 bytes (8 chars) of double sha256 hash of given hex string
(define (get-checksum hstr) (substring hstr 0 8))
(define (sha256x2/hex hstr) (sha256/hex (sha256/hex hstr)))
(define (compute-checksum hstr) (get-checksum (sha256x2/hex hstr)))
(define (add-checksum hstr) (string-append hstr (compute-checksum hstr)))

(define (hex=? str1 str2) (string=? (string-upcase str1) (string-upcase str2)))

;; computes base58 addr from uncompressed (hex) priv key
(define priv-key->addr
  (compose hex-str->base58-str 
           add-checksum 
           add-version0
           hash160/hex
           priv-key->pub-key))
;; computes base58 addr from compressed (hex) priv key
(define priv-key->addr/compressed
  (compose hex-str->base58-str 
           add-checksum 
           add-version0
           hash160/hex
           priv-key->pub-key/compressed))

;; WIF processing -------------------------------------------------------------

;; wif is in base58, priv key is in hex
(define (wif->priv-key wif) (substring (base58-str->hex-str wif) 2 66))

;; wif is in base58
(define (wif-compressed? wif)
  (define len (string-length wif))
  (when (not (or (= len 51) (= len 52)))
    (error 'wif-compressed? "invalid WIF: ~a\n" wif))
  (define c (string-ref wif 0))
  (or (char=? c #\K) (char=? c #\L)))

;; splits wif into prefix + checksum
;; wif is in base58 but results are in  hex
(define (wif-split-checksum wif)
  (define wif/hex (base58-str->hex-str wif))
  (cond [(wif-compressed? wif)
         (values (substring wif/hex 0 68) (substring wif/hex 68 76))]
        [else
         (values (substring wif/hex 0 66) (substring wif/hex 66 74))]))
  
;; wif is in base58
(define (wif-checksum-ok? wif)
  (define-values (wif-prefix wif-checksum) (wif-split-checksum wif))
  (hex=? wif-checksum (compute-checksum wif-prefix)))
         
;; wif and addr are base58
(define (wif->addr wif)
  (define priv (wif->priv-key wif))
  (if (wif-compressed? wif) 
      (priv-key->addr/compressed priv)
      (priv-key->addr priv)))

(module+ test
  (require rackunit)
  ;; bitcoin wiki example
  (define priv-key 
    "18E14A7B6A307F426A94F8114701E7C8E774E7F9A47E2C2035DB29A206321725")
  (define addr "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  
  (check-equal? (priv-key->addr priv-key) addr)
  
  (define wif/comp "L3S9k3w3gMj2gBUWvPQQTC74giRTjQU3EEXF51f17qQskgJsF7Qe")
  (define addr/comp "1G9dbCmxtbaBQACVgcHWHJgyr8ZNCiVL9j")
  (check-true (wif-checksum-ok? wif/comp))
  (check-equal? (wif->addr wif/comp) addr/comp)
  (define wif/uncomp "5KDwznXNT8sJbhtYheFNB1ho9Yb69hfJGgmTkW9cNVBr7LxFEje")
  (define addr/uncomp "15YzfXwEg5STm3GtEh87LAyzNbpVpdx5eN")
  (check-true (wif-checksum-ok? wif/uncomp))
  (check-equal? (wif->addr wif/uncomp) addr/uncomp)
  
  (check-exn exn:fail? (lambda () (wif-compressed? "123")))
  (check-true (wif-compressed? wif/comp))
  (check-false (wif-compressed? wif/uncomp)))
