(define-trait stackpot-pot-trait (
  (get-pot-participants
    ()
    (
      response       (list 100 (optional {
      participant: principal,
      amount: uint,
    }))
      (list 0 (optional {
      participant: principal,
      amount: uint,
    }))
    )
  )
))
