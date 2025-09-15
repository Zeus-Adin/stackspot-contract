(use-trait stackpot-pot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pot-trait.stackpot-pot-trait)
(define-trait stackspot-distribution-trait 
    (
        (dispatch-principals-and-rewards (uint <stackpot-pot-trait> {pot-id: uint, pot-name: (string-ascii 255), pot-owner: principal, pot-contract: principal}) (response bool uint))
    )
)