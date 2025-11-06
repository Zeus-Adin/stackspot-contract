(define-trait stackspot-trait 
    (
        (get-pot-admin () (response principal principal))
        (get-pot-participants () (response (list 100 (optional {participant: principal, amount: uint})) (list 0 (optional {participant: principal, amount: uint}))))
        (get-pot-treasury () (response principal principal))
        (get-pot-id () (response (optional uint) (optional uint)))
        (get-pot-starter-principal () (response (optional principal) (optional principal)))
        (get-pot-value () (response uint uint))
        (get-pot-claimer-principal () (response principal principal))
        (get-last-participant () (response uint uint))
        (get-by-id-helper (uint) (response (optional {participant: principal, amount: uint}) (optional {participant: principal, amount: uint})))
    )
)