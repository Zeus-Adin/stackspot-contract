(define-constant UNAUTHORIZED (err u100))
(define-constant author tx-sender)

(define-map supported-pools principal bool)
(define-read-only (is-supported (pool principal)) 
    (map-get? supported-pools pool)
)
(define-public (add-supported-pool (pool principal)) 
    (begin 
        (asserts! (is-eq tx-sender author) UNAUTHORIZED)
        (map-insert supported-pools pool true)
        (ok true)
    )
)