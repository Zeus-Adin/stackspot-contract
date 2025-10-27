(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-distribution-trait.stackspot-distribution-trait)
(use-trait stackspot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)

;; --- Not Found
(define-constant ERR_NOT_FOUND (err u1001))
;; --- Authorization
(define-constant ERR_UNAUTHORIZED (err u1101))

;; --- Distribution Admin
(define-constant pot-distribution-admin (as-contract tx-sender))
(define-constant allowed-caller .stackspots)

;; Private helper function that returns participant principals
(define-private (return-participant-principals (participant-value (optional {participant: principal, amount: uint})) (result (response bool uint)))
    (let 
        (
            (participant (unwrap! (get participant participant-value) ERR_NOT_FOUND))
            (principal-amount (unwrap! (get amount participant-value) ERR_NOT_FOUND))
        )
        (try! (stx-transfer-memo? principal-amount tx-sender participant
            (unwrap! (to-consensus-buff? "participant principal") ERR_NOT_FOUND)
        ))
        result
    )
)

(define-public (dispatch-principals (contract <stackspot-trait>))
    (let 
        (
            (pot-id (unwrap! (contract-call? contract get-pot-id) ERR_NOT_FOUND))
            (pot-treasury (unwrap! (contract-call? contract get-pot-treasury) ERR_NOT_FOUND))
            (participants (unwrap! (contract-call? contract get-pot-participants) ERR_NOT_FOUND))           
        )
        ;; Validate's if the pot treasury is the same as the pot treasury address
        (asserts! (is-eq pot-treasury tx-sender) ERR_UNAUTHORIZED)
        ;; Validate's if the contract caller is the allowed caller
        (asserts! (is-eq contract-caller allowed-caller) ERR_UNAUTHORIZED)

        ;; ;; Dispatch participants principals
        (try! (fold return-participant-principals participants (ok true)))

        ;; ;; ;; Print event
        (print {
            event: "dispatch-principals",
            pot-id: pot-id,
            participants: participants,
            contract: pot-treasury,
            pot-treasury: pot-treasury,
            contract-caller: contract-caller,
            tx-sender: tx-sender,
        })
        ;; Execution complete
        (ok true)
    )
)

(define-public (dispatch-rewards (winner-values {participant: principal, amount: uint}) (contract <stackspot-trait>))
    (let 
        (
            (pot-treasury (unwrap! (contract-call? contract get-pot-treasury) ERR_NOT_FOUND))
            (treasury-balance (stx-get-balance pot-treasury))
            (total-contributed-value (unwrap! (contract-call? contract get-pot-value) ERR_NOT_FOUND))
            (pot-yeild (if (> treasury-balance total-contributed-value) (- treasury-balance total-contributed-value) u0))
            (participants-count (unwrap! (contract-call? contract get-last-participant) ERR_NOT_FOUND))
            (pot-id (unwrap! (contract-call? contract get-pot-id) ERR_NOT_FOUND))

            ;; Pot Starter Values
            (pot-starter-address (unwrap! (contract-call? contract get-pot-starter-principal) ERR_NOT_FOUND))
            (pot-starter-reward (* (/ pot-yeild u100) u5))

            ;; Claimer Values
            (claimer-address (unwrap! (contract-call? contract get-pot-claimer-principal) ERR_NOT_FOUND))
            (claimer-reward (* (/ pot-yeild u100) u5))

            ;; Winner Values
            (winner-address (get participant winner-values))
            (winner-reward (* (/ pot-yeild u100) u90))
        )
        ;; Validate's if the pot treasury is the same as the pot treasury address
        (asserts! (is-eq pot-treasury tx-sender) ERR_UNAUTHORIZED)
        ;; Validate's if the contract caller is the allowed caller
        (asserts! (is-eq contract-caller allowed-caller) ERR_UNAUTHORIZED)

        ;; Dispatch pot starter reward
        (if (> pot-starter-reward u0)
            (begin 
                (try! (stx-transfer-memo? pot-starter-reward pot-treasury pot-starter-address (unwrap! (to-consensus-buff? "pot starter reward") ERR_NOT_FOUND)))
                true
            )
            false
        )

        ;; ;; Dispatch claimer reward
        (if (> claimer-reward u0)
            (begin 
                (try! (stx-transfer-memo? claimer-reward pot-treasury claimer-address (unwrap! (to-consensus-buff? "claimer reward") ERR_NOT_FOUND)))
                true
            )
            false
        )

        ;; ;; Dispatch winner reward
        (if (> winner-reward u0)
            (begin 
                (try! (stx-transfer-memo? winner-reward pot-treasury winner-address (unwrap! (to-consensus-buff? "winner reward") ERR_NOT_FOUND)))
                true
            )
            false
        )

        ;; Print event
        (print {
            event: "dispatch-rewards",
            pot-id: pot-id,
            pot-starter-address: pot-starter-address,
            pot-starter-reward: pot-starter-reward,
            claimer-address: claimer-address,
            claimer-reward: claimer-reward,
            winner-address: winner-address,
            winner-reward: winner-reward,
            contract: contract,
            pot-treasury: pot-treasury,
            contract-caller: contract-caller,
            tx-sender: tx-sender,
        })
        ;; Execution complete
        (ok true)
    )
)

(define-public (delegate-treasury (contract <stackspot-trait>) (delegate-to principal)) 
    (let (
            (treasury-address (unwrap! (contract-call? contract get-pot-treasury) ERR_NOT_FOUND))
            (amount-ustx (stx-get-balance treasury-address))            
            (until-burn-ht none)
            (pox-addr none)
        )
        ;; Validate's if the pot treasury is the same as the pot treasury address
        (asserts! (is-eq treasury-address tx-sender) ERR_UNAUTHORIZED)
        ;; Validate's if the contract caller is the allowed caller
        (asserts! (is-eq contract-caller allowed-caller) ERR_UNAUTHORIZED)

        (match (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sim-pox delegate-stx amount-ustx delegate-to until-burn-ht pox-addr)
            ok (ok true)
            err (err (to-uint err))
        )
    )
)

(define-public (withdraw-from-pot (participant principal) (amount uint) (contract <stackspot-trait>))
    (let 
        (
            (treasury-address (unwrap! (contract-call? contract get-pot-treasury) ERR_NOT_FOUND))
            (treasury-balance (stx-get-balance treasury-address))
        )
        ;; Validate's if the pot treasury is the same as the pot treasury address
        ;; Validate's if the contract caller is the allowed caller
        (asserts! (is-eq treasury-address tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller allowed-caller) ERR_UNAUTHORIZED)

        (try! (stx-transfer-memo? amount treasury-address participant (unwrap! (to-consensus-buff? "withdraw from pot") ERR_NOT_FOUND)))
        (ok true)
    )
)