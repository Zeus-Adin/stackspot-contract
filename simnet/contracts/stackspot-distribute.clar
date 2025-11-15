(use-trait stackspot-trait .stackspot-trait.stackspot-trait)

;; --- Not Found
(define-constant ERR_NOT_FOUND (err u1001))
;; --- Authorization
(define-constant ERR_UNAUTHORIZED (err u1101))
(define-constant ERR_POT_CLAIM_NOT_REACHED (err u1402))
(define-constant ERR_POOL_ENTRY_PASSED (err u1403))
(define-constant ERR_INSUFFICIENT_POT_REWARD (err u1304))
(define-constant ERR_DISPATCH_FAILED (err u1108))
(define-constant ERR_LOG_FAILED (err u1109))
;; Platform Address
(define-constant platform-address tx-sender)

;; Get PoX Info and return pool config
;; Testnet version
(define-read-only (get-pox-info) (unwrap-panic (contract-call? .sim-pox-4 get-pox-info)))
(define-read-only (get-pool-config) 
    (let 
        (
            (pox-details (get-pox-info))
            (cycle (get reward-cycle-id pox-details))
            (first (get first-burnchain-block-height pox-details))
            (cycle-len (get reward-cycle-length pox-details))
            (prepare-len (get prepare-cycle-length pox-details))
            (cycle-start (+ first (* cycle cycle-len)))
            (next-cycle-start (+ first (* (+ cycle u1) cycle-len)))
        )
        (ok {
            join-end: (- (- next-cycle-start prepare-len) u300),
            prepare-start: (- next-cycle-start prepare-len),
            cycle-end: next-cycle-start,
            reward-release: (+ next-cycle-start u432)
        })
    )
)

;; pot Join Stop validation
(define-read-only (validate-can-pool-pot) 
    (let 
        (
            (pool-config (unwrap! (get-pool-config) false))
            (join-end (get join-end pool-config))
        ) 
       (asserts! (< burn-block-height join-end) false)
       true
    )
)

;; ;; Pot Claim Start validation
(define-read-only (validate-can-claim-pot) 
    (let 
        (
            (pool-config (unwrap! (get-pool-config) false))
            (reward-release (get reward-release pool-config))
        ) 
       (asserts! (> burn-block-height reward-release) false)
       true
    )
)

;; ;; Private helper function that returns participant principals
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
        (asserts! (is-eq contract-caller .stackspots) ERR_UNAUTHORIZED)

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

(define-private (dispatch-rewards-with-sbtc (amount uint) (from principal) (to principal) (memo (optional (buff 32)))) 
    (contract-call? .sbtc-token transfer amount from to memo)
)

(define-public (dispatch-rewards (contract <stackspot-trait>))
    (let 
        (

            (pot-details (unwrap! (contract-call? contract get-pot-details) ERR_NOT_FOUND))

            (pot-treasury (get pot-address pot-details))
            (pot-yeild (unwrap! (contract-call? .sbtc-token get-balance pot-treasury) ERR_NOT_FOUND))

            (pot-id (get pot-id pot-details))

            ;; Pot Fee
            (pot-owner-address (get pot-owner pot-details))
            (pot-fee (* (/ pot-yeild u100) u5))

            ;; Platform Royalty
            (platform-royalty-address platform-address)
            (platform-royalty-reward (* (/ pot-yeild u100) u1))

            ;; Pot Starter Values
            (pot-starter-address (unwrap! (get pot-starter-address pot-details) ERR_NOT_FOUND))
            (pot-starter-reward (* (/ pot-yeild u100) u2))

            ;; Claimer Values
            (claimer-address (unwrap! (get pot-claimer-address pot-details) ERR_NOT_FOUND))
            (claimer-reward (* (/ pot-yeild u100) u2))

            ;; Winner Values
            (winner-address (unwrap! (get winner-address (get winners-values pot-details)) ERR_NOT_FOUND))
            (winner-reward (* (/ pot-yeild u100) u90))
        )

        ;; Validate's if the pot claim is not reached
        ;; Validate's if the pot yeild is greater than 0
        ;; Validate's if the pot treasury is the same as the tx-sender
        ;; Validate's if the contract caller is the allowed caller
        (asserts! (validate-can-claim-pot) ERR_POT_CLAIM_NOT_REACHED)
        (asserts! (> pot-yeild u0) ERR_INSUFFICIENT_POT_REWARD)
        (asserts! (is-eq pot-treasury tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller .stackspots) ERR_UNAUTHORIZED)

        ;; Dispatch platform royalty reward
        (asserts! 
            (if (> platform-royalty-reward u0)
                (is-ok (dispatch-rewards-with-sbtc platform-royalty-reward pot-treasury platform-royalty-address (to-consensus-buff? "platform royalty reward")))
                false
            ) 
            ERR_DISPATCH_FAILED
        )

        ;; Dispatch pot fee reward
        (asserts! 
            (if (> pot-fee u0)
                (is-ok (dispatch-rewards-with-sbtc pot-fee pot-treasury pot-owner-address (to-consensus-buff? "pot fee reward")))
                false
            ) 
            ERR_DISPATCH_FAILED
        )
        ;; Dispatch pot starter reward
        (asserts! 
            (if (> pot-starter-reward u0)           
                (is-ok (dispatch-rewards-with-sbtc pot-starter-reward pot-treasury pot-starter-address (to-consensus-buff? "pot starter reward")))             
                false
            )  
            ERR_DISPATCH_FAILED
        )

        ;; Dispatch claimer reward
        (asserts! 
            (if (> claimer-reward u0)
                (is-ok (dispatch-rewards-with-sbtc claimer-reward pot-treasury claimer-address (to-consensus-buff? "claimer reward")))
                false
            ) 
            ERR_DISPATCH_FAILED
        )

        ;; Dispatch winner reward
        (asserts! 
            (if (> winner-reward u0)
                (is-ok (dispatch-rewards-with-sbtc winner-reward pot-treasury winner-address (to-consensus-buff? "winner reward")))
                false
            ) 
            ERR_DISPATCH_FAILED
        )

        (asserts! (is-ok (contract-call? .stackspot-winners log-winner (unwrap! (to-consensus-buff? 
            {
                ;; Pot Values
                event: "claim-pot-reward",
                ;; Pot Round Values
                pot-participants-count: (get pot-participants-count pot-details), 
                pot-participants: (get pot-participants pot-details),
                pot-value: (get pot-value pot-details),
                pot-yield-amount: pot-yeild,
                ;; Winner Values
                winners-values:  (unwrap! (get winners-values pot-details) ERR_NOT_FOUND),
                ;; Starter Values
                starter-address: pot-starter-address,
                starter-reward-amount: pot-starter-reward,
                ;; Claimer Values
                claimer-address: claimer-address,
                claimer-reward-amount: claimer-reward,
                ;; Pot Values
                pot-id: pot-id,
                pot-address: pot-treasury,
                pot-owner: pot-owner-address,                
                ;; Pot Config Values
                pot-name: (get pot-name pot-details),
                pot-type: (get pot-type pot-details),
                pot-cycle: (get pot-cycle pot-details),
                pot-reward-token: (get pot-reward-token pot-details),
                pot-min-amount: (get pot-min-amount pot-details),
                pot-max-participants: (get pot-max-participants pot-details),
                ;; Pot Origination Values
                origin-contract-sha-hash: (get origin-contract-sha-hash pot-details),
                stacks-block-height: (get stacks-block-height pot-details),
                burn-block-height: (get burn-block-height pot-details)        
            }
        ) ERR_NOT_FOUND))) 
            ERR_LOG_FAILED
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

        (ok true)
    )
)

(define-public (delegate-treasury (contract <stackspot-trait>) (delegate-to principal)) 
    (let 
        (
            (treasury-address (unwrap! (contract-call? contract get-pot-treasury) ERR_NOT_FOUND))
            (amount-ustx (stx-get-balance treasury-address))
        )

        ;; Validate's if the pool entry is passed
        ;; ;; Validate's if the pot treasury is the same as the pot treasury address
        ;; ;; Validate's if the contract caller is the allowed caller
        (asserts! (validate-can-pool-pot) ERR_POOL_ENTRY_PASSED)
        (asserts! (is-eq treasury-address tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller .stackspots) ERR_UNAUTHORIZED)

        (print {
            event: "delegate-treasury",
            treasury-address: treasury-address,
            amount-ustx: amount-ustx,
            contract: contract,
            delegate-to: delegate-to,
            tx-sender: tx-sender,
            contract-caller: contract-caller,
        })

        ;; Delegate pot values to pool
        ;; (match (contract-call? .sim-pox4-multi-pool-v1 delegate-stx amount-ustx (unwrap! (to-consensus-buff? {c: "sbtc"}) ERR_NOT_FOUND))
        ;;     ok (ok true)
        ;;     error (err error)
        ;; )
        (ok true)
    )
)