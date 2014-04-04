#lang racket/base

(provide (all-defined-out))

(define HEX-CHARS "0123456789ABCDEF")
(define BASE58-CHARS 
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

(define (anycase=? c1 c2) (char=? (char-upcase c1) (char-upcase c2)))

(define (hex-char->num ch)
  (define index 
    (for/first ([(c n) (in-indexed HEX-CHARS)] #:when (anycase=? c ch)) n))
  (or index (error 'hex-char->num "invalid hex char: ~a\n" ch)))

(define (hex-str->num hstr)
  (for/fold ([num 0]) ([ch (in-string hstr)]) 
    (+ (* 16 num) (hex-char->num ch))))

(define (num->base58-char n)
  (when (or (< n 0) (>= n 58))
    (error 'num->base58-char "cannot convert to base-58: ~a\n" n))
  (string-ref BASE58-CHARS n))

(define (num->base58-str.v0 n)
  (list->string
    (reverse
     (let loop ([n n])
       (define-values (q r) (quotient/remainder n 58))
       (if (zero? q)
           (list (num->base58-char r))
           (cons (num->base58-char r) (loop q)))))))
(define (num->base58-str n) 
  (if (zero? n) "" (num->base58-str.v0 n)))


(define (count-leading-zeros str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\0 c))) 1))

(define (hex-str->base58-str.v0 hstr) 
  (num->base58-str.v0 (hex-str->num hstr)))
(define (hex-str->base58-str hstr)
  (define num-leading-ones (quotient (count-leading-zeros hstr) 2))
  (define leading-ones (make-string num-leading-ones #\1))
  (string-append leading-ones (hex-str->base58-str.v0 hstr)))

;; test suite, run with command: raco test base58.rkt
(module+ test
  (require rackunit)
  
  (define bwiki-hex-addr "00010966776006953D5567439E5E39F86A0D273BEED61967F6")

  (check-equal? (hex-str->num bwiki-hex-addr)
                25420294593250030202636073700053352635053786165627414518)
  (check-equal? (hex-str->base58-str.v0 bwiki-hex-addr)
                "6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  (check-equal? (hex-str->base58-str bwiki-hex-addr)
                "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  
  ;; check char->num fns
  (check-equal? (hex-char->num #\F) 15)
  (check-equal? (hex-char->num #\f) 15)
  (check-equal? (hex-char->num #\0) 0)
  (check-equal? (hex-char->num #\A) 10)
  (check-equal? (hex-char->num #\a) 10)
  (check-exn exn:fail? (λ () (hex-char->num #\h)))
  (check-exn exn:fail? (λ () (hex-char->num #\!)))
  (check-exn exn:fail? (λ () (hex-char->num #\K)))
  (check-exn exn:fail? (λ () (hex-char->num #\")))
  ;; (check-equal? (base58-char->num #\1) 0)
  ;; (check-equal? (base58-char->num #\A) 9)
  ;; (check-equal? (base58-char->num #\a) 33)
  ;; (check-exn exn:fail? (λ () (base58-char->num #\")))
  ;; (check-exn exn:fail? (λ () (base58-char->num #\0)))
  ;; (check-exn exn:fail? (λ () (base58-char->num #\O)))
  ;; (check-exn exn:fail? (λ () (base58-char->num #\I)))
  ;; (check-exn exn:fail? (λ () (base58-char->num #\l)))
  
  ;; check num->char fns
  (check-equal? (num->base58-char 0) #\1)
  (check-equal? (num->base58-char 10) #\B)
  (check-equal? (num->base58-char 57) #\z)
  (check-exn exn:fail? (lambda () (num->base58-char -1)))
  (check-exn exn:fail? (lambda () (num->base58-char 58)))
  (check-exn exn:fail? (lambda () (num->base58-char 59)))
  
  ;; check leading digits
  (check-equal? (count-leading-zeros "") 0)
  (check-equal? (count-leading-zeros "1") 0)
  (check-equal? (count-leading-zeros "11") 0)
  (check-equal? (count-leading-zeros "0") 1)
  (check-equal? (count-leading-zeros "01") 1)
  (check-equal? (count-leading-zeros "00") 2)
  (check-equal? (count-leading-zeros "001") 2)
  )
