(define-public (log-participant (participant-values {
  pot-id: uint,
  participant-id: uint,
  participant-address: principal,
  participant-amount: uint,
  participant-timestamp: uint,
}))
  (ok (print participant-values))
)
