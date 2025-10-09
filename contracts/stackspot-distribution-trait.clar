(use-trait stackpot-pot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pot-trait.stackpot-pot-trait)
(define-trait stackspot-distribution-trait 
    (
        (dispatch-principals (<stackpot-pot-trait>) (response bool uint))
        (dispatch-rewards ({participant: principal, amount: uint} <stackpot-pot-trait>) (response bool uint))
    )
)