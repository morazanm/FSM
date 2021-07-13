#lang racket
(require (for-syntax racket/syntax syntax/stx syntax/parse racket/list racket/string))
(provide factory)

(begin-for-syntax
  ;; transform-id :: syntax -> synatx
  ;; Purpose: trandformes the syntax into 'a-<randome_number>'
  (define (transform-id id)
    (gensym "a-"))

  ;; transform-list :: syntax -> syntax-pair
  ;; syntax pair: '(identifier procedure/'NONE)
  ;; Purpse: if the syntax contains a procedure(i.e. number?) we
  ;;   return a new identifier and the origional
  (define (transform-list stx)
    (for/list ([val (syntax->list stx)])
      (if (symbol? (syntax->datum val))
               (let ([s ((compose symbol->string syntax->datum) val)])
                 (cond
                   [(string-contains? (substring s (sub1 (string-length s))) "?") (list (transform-id val) val)]
                   [else (list val 'NONE)]))
          (list val 'NONE))))

  ;; parse-match :: synatx -> listof(listof(syntax-pairs))
  ;; Purpose: converts the syntax to pairs for parsing the match statment for
  ;;  guard clauses
  (define (parse-match clause)
    (syntax-parse clause
      [(list (s ...) ...) (stx-map (lambda (inner) (transform-list inner))
                                   #'((s ...) ...))]
      [(s ...) (list (transform-list #'(s ...)))]))

  ;; build-guard :: listof(listof(pairs)) -> synatx
  ;; Purpose: builds the guard clause for the function. returns false if
  ;;  there are not any guard clauses to be made.
  (define (build-guard lop)
    (define guards (flatten
                    (filter-map (lambda (outter)
                                  (let ([vals (filter-map (lambda (inner)
                                                            (if (eq? (cadr inner) 'NONE)
                                                                #f
                                                                (with-syntax ([t1 (second inner)]
                                                                              [t2 (first inner)])
                                                                  #`(t1 t2)))) outter)])
                                    (if (empty? vals) #f vals))) lop)))
    (define guard-clause
      (cond
        [(= 1 (length guards)) (with-syntax([t (car guards)])
                                 #`(#:when t))]
        [(> (length guards) 1)
         #`(#:when (and #,@guards))]
        [else #'(void)]))

    (if (empty? guards)
        #f
        #`(#,@guard-clause)))
        
  ;; transform-match :: syntax syntax -> syntax
  ;; Purpose: takes in a syntax and converts it the the propper racket match synatx
  (define (transform-match clause func)
    (let* ((parsed-match (parse-match clause))
           ;; fields are the first of the syntax pairs
           (fields (let ([t (map (lambda (outter) (map (lambda (inner) (car inner)) outter)) parsed-match)])
                     (if (eq? 1 (length t))
                         (car t)
                         t)))
           ;; the guard cause syntax i.e. #:when ...
           (guard-clause (build-guard parsed-match)))
      (with-syntax ([f func])
        (if guard-clause ;; if there is not a guard clause then dont add it...
            (syntax-parse fields
              [((field ...) ...) #`[(list (field ...) ...) #,@guard-clause (f data)]]
              [(field ...) #`[(field ...) #,@guard-clause (f data)]])
            (syntax-parse fields
              [((field ...) ...) #`[(list (field ...) ...) (f data)]]
              [(field ...) #`[(field ...) (f data)]]))))))

;; factory :: synatx -> syntax
;; Purpose: This is the marco that converts the factory syntax into the approperate racket
;;  function. The name of the function is: <name supplied>-factory. See examples below for
;;  more details.
(define-syntax (factory stx)
  (define-syntax-class wc
    #:description "basic symbol"
    (pattern _))
  (define-syntax-class lowc
    #:description "valid lou"
    (pattern (patt:wc ...))
    (pattern ((npatt:wc ...) ...)))

  (syntax-parse stx
    [(_ factory-name:id (p:lowc ... <- func:id) ...)
     #:with fact-fn-name (format-id #'factory-name "~a-factory" #'factory-name)
     #:with (conds ...) (stx-map (lambda (p f)
                                   (syntax-parse p
                                     [(((s ...) ...))
                                      #:with fn f
                                      #:with t (transform-match #'(list (list s ...) ...) #'fn)
                                      #'t]
                                     [((s ...))
                                      #:with fn f
                                      #:with t (transform-match #'(list s ...) #'fn)
                                      #'t]))
                                 #'((p ...) ...)
                                 #'(func ...))
     #`(define (fact-fn-name data)
         (match (car data)
           conds ...
           [else (error "Invalid pattern supplied")]))]))