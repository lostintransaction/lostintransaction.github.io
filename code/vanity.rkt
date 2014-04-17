#lang racket/base
(require (only-in openssl/sha1 bytes->hex-string))
(require "priv2addr.rkt" "base58.rkt")
(provide (all-defined-out))

(define (add-mainnet80 str) (string-append "80" str))
(define (add-compression-flag str) (string-append str "01"))

(define (random-byte) (random 256))

;; generates raw 32 byte private key (in hex)
(define (random-priv-key)
  (bytes->hex-string (apply bytes (for/list ([i 32]) (random-byte)))))

;; converts raw priv key (in hex) to wif (in base58)
(define (priv-key->wif priv)
  (hex-str->base58-str (add-checksum (add-mainnet80 priv))))
(define (priv-key->wif/compressed priv)
  (hex-str->base58-str (add-checksum (add-compression-flag (add-mainnet80 priv)))))

(define (get-vanity-addr prefix #:tries [tries 1000000])
  (define prefix1 (string-append "1" prefix))
  (define prefix-len (string-length prefix1))
  (let loop ([n tries])
    (if (zero? n)
        (printf "\nCouldn't find matching address in ~a tries\n" tries)
        (let* ([priv (random-priv-key)]
               [priv/wif (priv-key->wif/compressed priv)]
               [addr (wif->addr priv/wif)])
          (if (string=? (substring addr 0 prefix-len) prefix1)
              (values priv priv/wif addr)
              (begin
                (printf "~a: ~a\n" n addr)
                (loop (sub1 n))))))))

;; usage racket vanity.rkt <desired prefix (without the leading '1')>
(module+ main
  (define args (current-command-line-arguments))
  (define num-args (vector-length args))
  (cond
   [(zero? num-args)
    (printf "Please provide an address prefix.\n")]
   [(= num-args 1)
    (define arg (vector-ref args 0))
    (define-values (priv priv/wif addr) (get-vanity-addr arg))
    (printf "Address found! -----------------------------------------------\n")
    (printf "private key: ~a\n" priv)
    (printf "private key (WIF): ~a\n" priv/wif)
    (printf "public address: ~a\n" addr)]
   [else (printf "Please only provide one input.\n")]))
