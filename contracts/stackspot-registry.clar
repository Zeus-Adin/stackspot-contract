(define-constant ERR_UNAUTHORIZED (err u1101))

(define-public (log-pot (participant-values {
    pot-id: uint,
    pot-address: principal,
    contract-sha-hash: (string-ascii 64),
    pot-owner: principal,
    pot-name: (optional (string-ascii 255)),
    pot-version: (buff 1),
    pot-hash-bytes: (buff 20),
    pot-platform-contract-fee: uint,
    pot-registry-timestamp: uint,
}))
    (begin 
        (asserts! (is-eq contract-caller .stackspots) ERR_UNAUTHORIZED)
        (print participant-values)
        (ok true)
    )
)