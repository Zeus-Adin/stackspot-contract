(define-public (log-pot (participant-values {
    pot-id: uint,
    pot-address: principal,
    pot-owner: principal,
    pot-name: (optional (string-ascii 255)),
    pot-version: (buff 1),
    pot-hash-bytes: (buff 20),
    pot-platform-contract-fee: uint,
    pot-registry-timestamp: uint,
}))
    (ok (print participant-values))
)