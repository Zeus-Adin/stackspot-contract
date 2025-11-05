(define-constant ERR_UNAUTHORIZED (err u1101))

(define-public (log-winner (winner-values {
    ;; Pot Values
    pot-id: uint,
    pot-admin: principal,
    pot-round: uint,
    pot-participants: uint,
    pot-value: uint,
    ;; Pot Config Values
    pot-cycle: uint,
    pot-reward-token: (string-ascii 16),
    pot-min-amount: uint,
    pot-max-participants: uint,
    
    ;; Pot Starter Values
    pot-starter-address: principal,
    pot-starter-amount: uint,
    ;; Claimer Values
    claimer-address: principal,
    claimer-amount: uint,
    
    ;; Winner Values
    winner-id: uint,
    winner-address: principal,
    winner-amount: uint,
    winner-values: {
        amount: uint,
        participant: principal,
    },
    winner-timestamp: {
        stacks-block-height: uint,
        burn-block-height: uint,
    }
}))
    (begin
        (asserts! (is-eq contract-caller .stackspots) ERR_UNAUTHORIZED)
        (print winner-values)
        (ok true)
    )
)