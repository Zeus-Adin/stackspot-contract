(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-distribution-trait.stackspot-distribution-trait)
(use-trait stackpot-pot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pot-trait.stackpot-pot-trait)

(define-constant NOT_FOUND (err u104))
(define-constant UNAUTHORIZED (err u105))

(define-data-var pot-treasury-address principal tx-sender)

;; Private helper function that returns participant principals
(define-private (return-participant-principals
        (participant-value (optional {participant: principal, amount: uint}))
        (res (response bool uint))
    )
    (let (
            (participant (unwrap! (get participant participant-value) NOT_FOUND))
            (principal-amount (unwrap! (get amount participant-value) NOT_FOUND))
            (pot-treasury (var-get pot-treasury-address))
        )
        (try! (stx-transfer-memo? principal-amount pot-treasury participant (unwrap! (to-consensus-buff? "participant principal") NOT_FOUND)))
        res
    )
)

(define-public (dispatch-principals-and-rewards (pot-id uint) (contract <stackpot-pot-trait>) (pot-details {pot-id: uint, pot-name: (string-ascii 255), pot-owner: principal, pot-contract: principal}))
    (let 
        (
            (pot-treasury (get pot-contract pot-details))
            (participants (unwrap! (contract-call? contract get-pot-participants) NOT_FOUND))            
        )
        ;; Validate's if the pot treasury is the same as the pot treasury address
        (asserts! (is-eq pot-treasury tx-sender) UNAUTHORIZED)
        (asserts! (is-eq pot-treasury contract-caller) UNAUTHORIZED)

        ;; Set the pot treasury address
        (var-set pot-treasury-address pot-treasury)

        ;; Dispatch participants principals
        (try! (fold return-participant-principals participants (ok true)))

        ;; Print event
        (print {
            event: "dispatch-principals-and-rewards",
            pot-id: pot-id,
            participants: participants,
            contract: contract,
            pot-treasury: pot-treasury,
            pot-details: pot-details,
            contract-caller: contract-caller,
            tx-sender: tx-sender,
        })
        ;; Execution complete
        (ok true)
    )
)