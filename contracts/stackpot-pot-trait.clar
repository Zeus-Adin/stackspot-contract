(define-trait stackpot-pot-trait 
    (
        (join-pot (uint) (response bool uint))
        (reward-pot-winner () (response bool uint))
        (get-pot-participants () (response (list 100 principal) (list 100 principal)))
        (get-pot-value () (response uint uint))
        (get-pot-config () (response {cycles: uint, fee: uint, max-participants: uint} {cycles: uint, fee: uint, max-participants: uint}))        
    )
)