;; @caller wallet_1
(define-public (test-join-pot)
  (begin
    (try! (contract-call? .stackpot join-pot u100000000 tx-sender))
    (ok true)
  )
)

(define-public (test-start-jackpot)
  (begin
    (try! (contract-call? .stackpot start-jackpot))
    (try! (contract-call? .stackpot start-jackpot))
    (ok true)
  )
)
