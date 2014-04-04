#lang racket/base

(provide (all-defined-out))

(define HEX-CHARS "0123456789ABCDEF")
(define BASE58-CHARS 
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

(define (anycase=? c1 c2) (char=? (char-upcase c1) (char-upcase c2)))

;; convert char to base10
(define (hex-char->num ch)
  (define index 
    (for/first ([(c n) (in-indexed HEX-CHARS)] #:when (anycase=? c ch)) n))
  (or index (error 'hex-char->num "invalid hex char: ~a\n" ch)))

(define (base58-char->num ch)
  (define index 
    (for/first ([(c n) (in-indexed BASE58-CHARS)] #:when (char=? c ch)) n))
  (or index (error 'base58-char->num "invalid base58 char: ~a\n" ch)))

;; convert str to base10 num
(define (hex-str->num hstr)
  (for/fold ([num 0]) ([ch (in-string hstr)]) 
    (+ (* 16 num) (hex-char->num ch))))

(define (base58-str->num b58str)
  (for/fold ([num 0]) ([ch (in-string b58str)]) 
    (+ (* 58 num) (base58-char->num ch))))

;; convert base10 to base58 string
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

;; ----------------------------------------------------------------------------
;; convert hex string to base58 string
(define (count-leading-zeros str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\0 c))) 1))

;; bad first attempt
(define (hex-str->base58-str.v0 hstr) 
  (num->base58-str.v0 (hex-str->num hstr)))
;; only accepts byte-aligned (ie even-length) hex strings
(define (hex-str->base58-str hstr)
  (define num-leading-ones (quotient (count-leading-zeros hstr) 2))
  (define leading-ones (make-string num-leading-ones #\1))
  (string-append leading-ones (num->base58-str (hex-str->num hstr))))

;; convert base10 to hex string
(define (num->hex-char n)
  (when (or (< n 0) (>= n 16))
    (error 'num->hex-char "cannot convert to hex: ~a\n" n))
  (string-ref HEX-CHARS n))

(define (num->hex-str n)
  (if (zero? n) ""
      (list->string
        (reverse
          (let loop ([n n])
            (define-values (q r) (quotient/remainder n 16))
            (if (zero? q)
                (list (num->hex-char r))
                (cons (num->hex-char r) (loop q))))))))

;; ----------------------------------------------------------------------------
;; convert base58 string to hex string
(define (count-leading-ones str)
  (for/sum ([c (in-string str)] #:break (not (char=? #\1 c))) 1))

;; (define (base58-str->hex-str.v0 b58str) 
;;   (num->hex-str.v0 (base58-str->num b58str)))
(define (base58-str->hex-str b58str)
  (define hex-str/no-leading-zeros (num->hex-str (base58-str->num b58str)))
  (define num-leading-ones (count-leading-ones b58str))
  (define num-leading-zeros 
    (if (even? (string-length hex-str/no-leading-zeros))
        (* num-leading-ones 2)
        (add1 (* num-leading-ones 2))))
  (define leading-zeros (make-string num-leading-zeros #\0))
  (string-append leading-zeros hex-str/no-leading-zeros))

;; test suite, run with command: raco test base58.rkt
(module+ test
  (require rackunit)
  
  ;; example from bitcoin wiki article
  (define bwiki-hex-addr "00010966776006953D5567439E5E39F86A0D273BEED61967F6")
  (define bwiki-b58-addr "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")

  (check-equal? (hex-str->num bwiki-hex-addr)
                25420294593250030202636073700053352635053786165627414518)
  (check-equal? (hex-str->base58-str.v0 bwiki-hex-addr)
                "6UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  (check-equal? (hex-str->base58-str bwiki-hex-addr) bwiki-b58-addr)
  (check-equal? (base58-str->hex-str bwiki-b58-addr) bwiki-hex-addr)
  (check-equal? bwiki-b58-addr 
                (hex-str->base58-str (base58-str->hex-str bwiki-b58-addr)))
  (check-equal? bwiki-hex-addr 
                (base58-str->hex-str (hex-str->base58-str bwiki-hex-addr)))

  ;; corner cases
  ;; result should not be 11
  (check-equal? (hex-str->base58-str "00") "1")
  ;; hex-str->base58-str only accepts byte-aligned (ie even-length) hex strings
  (check-equal? (hex-str->base58-str "0") "")
  (check-equal? (base58-str->hex-str "1") "00")
  (check-equal? (base58-str->hex-str "11") "0000")
  
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
