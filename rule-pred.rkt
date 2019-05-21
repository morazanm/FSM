(module temp-rulepreds racket
  (require "constants.rkt")
  (require test-engine/racket-tests)
  (provide  check-rgrule check-cfgrule check-csgrule
            check-dfarule check-ndfarule check-pdarule check-tmrule
            ;check-pdarule check-tmrule
            )

  ;sub-member: (listof symbols) string num num --> boolean
  ;purpose: to check if a string is present in a list in symbolform
  (define (sub-member los str low high)
    (if (member (string->symbol (substring str low high)) los) #t #f))

  ;purpose: to check that the symbol given is composed
  ;         entirely of the first and second given list
  (define (allBoth sym list1 list2)
    (local [(define combined (append list1 list2))
            (define str (symbol->string sym))
            ;loop: number --> boolean
            ;purpose: to iterate through the word
            (define (loop end)
              (cond [(zero? end) #t]
                    [(sub-member combined str (sub1 end) end) (loop (sub1 end))]
                    [else #f]))
            ]
      (if (< (string-length str) 1) #f
          (loop (string-length str)))))

  (check-expect (allBoth 'AbAbA '(A) '(b)) #t)
  (check-expect (allBoth 'Abbbbbb '(b A) '()) #t)
  (check-expect (allBoth 'Edeee '(E) '(d i s es)) #f)


  ;purpose: to check that the symbol given is composed
  ;         of one symbol from the second list,
  ;         possibly followed by one symbol from the first list
  (define (oneAndOne sym list1 list2)
    (local [(define str (symbol->string sym))]
      (cond [(or (> (string-length str) 2)
                 (< (string-length str) 1)) #f]
            [else (and (sub-member list2 str 0 1)
                       (if (> (string-length str) 1)
                           (sub-member list1 str 1 2)
                           #t))])))

  (check-expect (oneAndOne 'aB '(A) '(b)) #f)
  (check-expect (oneAndOne 'Ab '(A) '(b)) #f)
  (check-expect (oneAndOne 'A '(A) '(b)) #f)
  (check-expect (oneAndOne 'b '(A) '(b)) #t)
  (check-expect (oneAndOne 'bA '(A) '(b)) #t)
  (check-expect (oneAndOne 'bB '(A B) '(a b)) #t)
  (check-expect (oneAndOne 'aA '(A B) '(a b)) #t)
  (check-expect (oneAndOne 'bA '(A) '(b)) #t)

  ;purpose: to check if the symbol is composed entirely of
  ;         symbols from the list
  (define (allOne sym list1)
    (allBoth sym list1 '()))

  (check-expect (allOne 'ajd '(a j d b s e)) #t)
  (check-expect (allOne 'abd '(e a d r s)) #f)

  ;purpose: to ensure that at least one symbol from a list is contained
  (define (hasOne sym list1)
    (local [(define str (symbol->string sym))
            ;loop: number --> boolean
            ;purpose: to iterate through the word
            (define (loop end)
              (cond [(zero? end) #f]
                    [(sub-member list1 str (sub1 end) end) #t]
                    [else (loop (sub1 end))]))]
      (loop (string-length str))))

  (check-expect (hasOne 'AbueopjsfaH '(y r l w p j s)) #t)
  (check-expect (hasOne 'asdfghjkl '(q w e r t y u i)) #f)

  ;purpose: to check any three-part rule
  (define (checkThrupples LHpred Mpred RHpred rules)
    (local [(define (theFold a-list)
              (foldl (lambda (x y) (string-append y (format "\n\t ~s" x))) "" a-list))
            (define LHerrors (filter (lambda (x) (not (LHpred (car x)))) rules))]
      (cond [(not (empty? LHerrors))
             (string-append "\n THE LHS OF THE FOLLOWING RULES ARE NOT VALID: "
                            (theFold LHerrors))]
            [else (local [(define Merrors (filter (lambda (x) (not (Mpred (cadr x)))) rules))]
                    (cond [(not (empty? Merrors))
                           (string-append "\n THE MIDDLES OF THE FOLLOWING RULES ARE NOT VALID: "
                                          (theFold Merrors))]
                          [else (local [(define RHerrors (filter (lambda (x) (not (RHpred (caddr x)))) rules))]
                                  (cond [(not (empty? RHerrors))
                                         (string-append "\n THE RHS OF THE FOLLOWING RULES ARE NOT VALID: "
                                                        (theFold RHerrors))]
                                        [else ""]))]))])))

  ;purpose: to make sure the rule is
  ;          (NTs ARROW (Ts V (Ts && NTs)))
  ;       or (S ARROW empty)
  (define (check-rgrule nts sigma delta)
    (checkThrupples (lambda (x) (member x nts))
                    (lambda (x) (equal? ARROW x))
                    (lambda (x) (oneAndOne x nts sigma))
                    delta))

  ;purpose: to make sure the rule is
  ;          (NTs ARROW (Ts V NTs)*)
  (define (check-cfgrule nts sigma delta)
    (checkThrupples (lambda (x) (member x nts))
                   (lambda (x) (equal? ARROW x))
                   (lambda (x) (or (equal? EMP x)
                                   (allBoth x nts sigma)))
                   delta))

  ;purpose: to make sure the rule is
  ;         (((NTs V Ts)* && NTs && (NTs V Ts)*) ARROW (NTs V Ts)*)
  (define (check-csgrule nts sigma delta)
    (checkThrupples (lambda (x) (and (hasOne x nts)
                                    (allBoth x nts sigma)))
                   (lambda (x) (equal? ARROW x))
                   (lambda (x) (or (equal? EMP x)
                                   (allBoth x nts sigma)))
                   delta))

  ;purpose: to make sure the rule is a state, a sigma element, and a state
  (define (check-dfarule states sigma delta)
    (checkThrupples (lambda (x) (member x states))
                   (lambda (x) (member x sigma))
                   (lambda (x) (member x states))
                   delta))

  ;purpose: to make sure the rule is a state, a sigma element or empty, and a state
  (define (check-ndfarule states sigma delta)
    (checkThrupples (lambda (x) (member x states))
                   (lambda (x) (or (equal? x EMP)
                                   (member x sigma)))
                   (lambda (x) (member x states))
                   delta))

  ;purpose: to make sure the rule is two lists
  ;      (state, sigma element or empty, gamma element or empty)
  ;      (state, gamma element or empty)
  (define (check-pdarule states sigma delta)
    "TBA"
    )

  ;purpose: to make sure the rule is two lists
  ;      (state, sigma elem or empty or space)
  ;      (state, sigma elem or empty or space)
  (define (check-tmrule states sigma delta)
    "TBA"
    )

  (test)
  )