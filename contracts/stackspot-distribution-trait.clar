(use-trait stackspot-trait .stackspot-trait.stackspot-trait)
(define-trait stackspot-distribution-trait 
    (
        (dispatch-principals (<stackspot-trait>) (response bool uint))
        (dispatch-rewards ({participant: principal, amount: uint} <stackspot-trait>) (response bool uint))
        (delegate-treasury (<stackspot-trait> principal) (response bool uint))
    )
)