(define-trait stackspot-trait 
    (
        (get-pot-admin () (response principal principal))
        (get-pot-participants () (response (list 1001 (optional {participant: principal, amount: uint})) (list 0 (optional {participant: principal, amount: uint}))))
        (get-pot-treasury () (response principal principal))
        (get-pot-id () (response (optional uint) (optional uint)))
        (get-pot-value () (response uint uint))
        (get-last-participant () (response uint uint))
        (get-by-id-helper (uint) (response (optional {participant: principal, amount: uint}) (optional {participant: principal, amount: uint})))
        (get-pot-details () (response 
            {
                pot-participants-count: uint,
                pot-participants: (list 1001 (optional {participant: principal, amount: uint})),
                pot-value: uint,
                ;; ;; Winner Values
                winners-values: (optional {
                    winner-id: uint,
                    winner-address: principal,
                }),
                ;; ;; Starter Values
                pot-starter-address: (optional principal),
                ;; ;; Claimer Values
                pot-claimer-address: (optional principal),
                ;; ;; Pot Values
                pot-id: (optional uint),
                pot-address: principal,
                pot-owner: principal,
                ;; ;; Pot Config Values
                pot-name: (string-ascii 255),
                pot-type: (string-ascii 255),
                pot-cycle: uint,
                pot-reward-token: (string-ascii 16),
                pot-min-amount: uint,
                pot-max-participants: uint,
                ;; ;; Pot Origination Values
                origin-contract-sha-hash: (string-ascii 255),
                stacks-block-height: uint,
                burn-block-height: uint
            }            

            uint          
        ))
    )
)