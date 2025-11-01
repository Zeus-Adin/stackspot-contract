(use-trait stackspot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)

(define-map audited-contracts principal bool)

(define-constant ERR_ADMIN_ONLY (err u1102))

(define-constant platform-admin tx-sender)

(define-public (add-audited-contract (contract <stackspot-trait>) (is-audited bool))
    (begin
        (asserts! (is-eq tx-sender platform-admin) ERR_ADMIN_ONLY)
        (ok (map-set audited-contracts (contract-of contract) is-audited))
    )
)

(define-public (remove-audited-contract (contract <stackspot-trait>))
    (begin
        (asserts! (is-eq tx-sender platform-admin) ERR_ADMIN_ONLY)
        (ok (map-delete audited-contracts (contract-of contract)))
    )
)

(define-read-only (is-audited-contract (contract <stackspot-trait>))
    (ok (default-to false (map-get? audited-contracts (contract-of contract))))
)