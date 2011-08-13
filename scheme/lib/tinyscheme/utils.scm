(define-macro (def fn . body)
  (define (def-form expr)
    (cond
      ((null? expr) '())
      (else (let (
        (x (car expr))
        (y (cdr expr)))
        (cond
          ((or (not (list? x)) (null? x))
            (cons x (def-form y)))
          (else
            (let (
              (current (car x))
              (next (cdr x)))
              (cond
                ((not (eq? current 'def))
                  (cons (cons current (def-form next)) (def-form y)))
                (else
                  (let (
                    (name (car next))
                    (body (cdr next)))
                    (cond
                      ((pair? name)
                        `((letrec (
                          (,(car name) (lambda (,@(cdr name)) ,@(def-form body))))
                          ,@(def-form y))))
                      (else
                        `((let (
                          (,name ,@(def-form body)))
                          ,@(def-form y)))))))))))))))
  `(define ,fn ,@(def-form body)))

(define-macro (mk~ . props)
  `(list
    ,@(map
      (lambda (prop)
        `(cons ,(car prop) (begin ,@(cdr prop))))
      props)))

(define-macro (mk . props)
  `(mk~
    ,@(map
      (lambda (prop)
        (cons `(quote ,(car prop)) (cdr prop)))
      props)))

(define-macro (xtn~ obj . props)
  `(append
    (mk~ ,@props)
    ,obj))

(define-macro (xtn obj . props)
  `(append
    (mk ,@props)
    ,obj))

(def (*colon-hook* member object)
  (cond
    ((list? object)
      (def found (assq member object))
      (cond
        (found
          (cdr found))
        (else
          (*error-hook* "property not found:" member))))
    ((environment? object)
      (eval member object))
    (else
      (*error-hook* "invalid property object" object member))))

(define-macro (:* expr . props)
  (let (
    (value (gensym)))
    `(let (
      (,value ,expr))
      ,(foldr
        (lambda (value prop)
          `(*colon-hook* (quote ,prop) ,value))
        value
        props))))

(def (:*~ value . props)
  (foldr
    (lambda (value prop)
      (*colon-hook* prop value))
    value
    props))

(define-macro (resolves-to object . tests)
  `(case (:* ,object type)
    ,@(map
      (lambda (test)
        (def type (car test))
        (def body (cdr test))
        (case type
          ('else
            `(else ,@body))
          (else
            `((quote ,type) ,@body))))
      tests)))

(def (filter f x)
  (cond
    ((null? x)
      '())
    ((f (car x))
      (cons (car x) (filter f (cdr x))))
    (else
      (filter f (cdr x)))))

(def (split-at f x found not-found)
  (def (rec x y)
    (cond
      ((null? x)
        (not-found))
      ((f (car x))
        (found (reverse y) (cdr x)))
      (else
        (rec (cdr x) (cons (car x) y)))))
  (rec x '()))

(def (with-error-handler handler code)
  (def old-handler *error-hook*)
  (set! *error-hook* handler)
  (def result (code))
  (set! *error-hook* old-handler)
  result)

(def (load-relative path)
  (def current (currently-loading-file))
  (def dir
    (list->string
      (reverse
        (split-at
          (lambda (x) (eqv? x #\/))
          (reverse (string->list current))
          (lambda (file dir) dir)
          (lambda () '(#\.))))))
  (def loading (string-append dir "/" path))
  (load loading))