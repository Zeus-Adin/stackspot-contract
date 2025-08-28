(define-public (log-winner (winner-values {
    ;; Pot Values
    pot-id: uint,
    pot-owner: principal,
    pot-round: uint,
    pot-participants: uint,
    pot-value: uint,
    ;; Pot Config Values
    pot-cycle: uint,
    pot-reward-token: (string-ascii 16),
    pot-fee: uint,
    pot-min-amount: uint,
    pot-max-participants: uint,
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
        (print winner-values)
        (ok true)
    )
)