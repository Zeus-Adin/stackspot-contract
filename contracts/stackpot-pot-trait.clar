(define-trait stackpot-pot-trait 
    (
        ;; (join-pot (uint) (response bool uint))
        ;; (reward-pot-winner () (response bool uint))
        (get-pot-participants () (response (list 100 (optional {participant: principal, amount: uint})) (list 0 (optional {participant: principal, amount: uint}))))
        ;; (get-pot-value () (response uint uint))
        ;; (get-pot-config () (response {cycles: uint, fee: uint, max-participants: uint} {cycles: uint, fee: uint, max-participants: uint}))  
    )
)