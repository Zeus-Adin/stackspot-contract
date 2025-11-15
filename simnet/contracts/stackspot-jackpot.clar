;; --- Traits
(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)
(use-trait stackspot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)

;; Errors
(define-constant ERR_NOT_FOUND (err u1001))
(define-constant ERR_UNAUTHORIZED (err u1101))
(define-constant ERR_ADMIN_ONLY (err u1102))
(define-constant ERR_PARTICIPANT_ONLY (err u1105))
(define-constant ERR_DUPLICATE_PARTICIPANT (err u1104))
(define-constant ERR_INVALID_ADDRESS (err u1201))
(define-constant ERR_INVALID_ARGUMENT_VALUE (err u1202))
(define-constant ERR_INVALID_POT (err u1203))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1301))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u1302))
(define-constant ERR_INSUFFICIENT_POT_BALANCE (err u1303))
(define-constant ERR_INSUFFICIENT_POT_REWARD (err u1304))
(define-constant ERR_POT_JOIN_CLOSED (err u1401))
(define-constant ERR_POT_CLAIM_NOT_REACHED (err u1402))
(define-constant ERR_POOL_ENTRY_PASSED (err u1403))
(define-constant ERR_POT_ALREADY_STARTED (err u1404))
(define-constant ERR_MAX_PARTICIPANTS_REACHED (err u1405))
(define-constant ERR_DELEGATE_FAILED (err u1406))
(define-constant ERR_DISPATCH_FAILED (err u1407))
(define-constant ERR_POT_JOIN_FAILED (err u1408))

;; Pot Starter Principal
;; Pot Claimer Principal
(define-data-var pot-starter-principal (optional principal) none)
(define-data-var pot-claimer-principal (optional principal) none)
(define-data-var winners-values (optional {winner-id: uint, winner-address: principal}) none)
;; Pot Rounds Counter
(define-data-var pot-rounds uint u0)

;; Pot Participants Maps
(define-map pot-participants-by-principal principal uint)
(define-map pot-participants-by-id uint {participant: principal, amount: uint})

(define-read-only (get-pot-details) 
    (ok 
        {
            pot-participants-count: (var-get last-participant),
            pot-participants: (unwrap! (get-pot-participants) ERR_NOT_FOUND),
            pot-value: (var-get total-pot-value),
            ;; Winner Values
            winners-values: (var-get winners-values),
            ;; Starter Values
            pot-starter-address: (var-get pot-starter-principal),
            ;; Claimer Values
            pot-claimer-address: (var-get pot-claimer-principal),
            ;; Pot Values
            pot-id: (unwrap! (get-pot-id) ERR_NOT_FOUND),
            pot-address: pot-treasury-address,
            pot-owner: pot-admin,
            ;; Pot Config Values
            pot-name: pot-name,
            pot-type: pot-type,
            pot-cycle: pot-cycle,
            pot-reward-token: "sbtc",
            pot-min-amount: pot-min-amount,
            pot-max-participants: pot-max-participants,
            ;; Pot Origination Values
            origin-contract-sha-hash: origin-contract-sha-hash,
            stacks-block-height: stacks-block-height,
            burn-block-height: burn-block-height,
        }
    )
)

;; Total Max Participants
;; Platform Address
;; Pot Treasury Address
(define-constant total-max-participants u1001)
(define-constant platform-address (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots get-platform-treasury))

(define-constant pot-treasury-address (as-contract tx-sender))
(define-read-only (get-pot-treasury)
    (ok pot-treasury-address)
)

;; Pot Admin
(define-constant pot-admin tx-sender)
(define-read-only (get-pot-admin)
    (ok pot-admin)
)

;; Get PoX Info and return pool config
(define-read-only (get-pox-info)
    (unwrap-panic (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sim-pox-4 get-pox-info))
)
(define-read-only (get-pool-config)
    (let (
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
            reward-release: (+ next-cycle-start u432),
        })
    )
)

;; pot Join Stop validation
(define-read-only (validate-can-pool-pot)
    (let (
            (pool-config (unwrap! (get-pool-config) false))
            (join-end (get join-end pool-config))
        )
        (asserts! (< burn-block-height join-end) false)
        true
    )
)

;; Pot Join Start validation
(define-read-only (validate-can-join-pot)
    (var-get locked)
)

;; Pot Claim Start validation
(define-read-only (validate-can-claim-pot)
    (let (
            (pool-config (unwrap! (get-pool-config) false))
            (reward-release (get reward-release pool-config))
        )
        (asserts! (> burn-block-height reward-release) false)
        true
    )
)

;; Locking Mechanism To Prevent Participants From Trying To Join The Pot While The Pot Is Stacked In Pool
(define-data-var locked bool false)
(define-read-only (is-locked)
    (var-get locked)
)

;; Last Participant Indexed In The Pot Participants By Id Map
(define-data-var last-participant uint u0)
(define-read-only (get-last-participant)
    (ok (var-get last-participant))
)

(define-read-only (get-configs)    
    {
        cycles: pot-cycle,
        min-amount: pot-min-amount,
        max-participants: pot-max-participants,
    }   
)

;; Pot Value
(define-data-var total-pot-value uint u0)
(define-read-only (get-pot-value)
    (ok (var-get total-pot-value))
)

;; Increment Pot Value
(define-private (add-pot-value (amount uint))
    (var-set total-pot-value (+ (var-get total-pot-value) amount))
)
;; Decrement Pot Value
(define-private (remove-pot-value (amount uint))
    (var-set total-pot-value (- (var-get total-pot-value) amount))
)

;; Read-Only public function that gets participant by index
(define-read-only (get-by-id-helper (n uint))
    (ok (map-get? pot-participants-by-id n))
)
(define-read-only (get-by-id-helper-private (n uint))
    (map-get? pot-participants-by-id n)
)

;; Read-Only public function that gets all participants
(define-read-only (get-pot-participants)
    (let (
            (participants-count (var-get last-participant))
            (n (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-vrf generate-list u0 participants-count))
            (participants (match n
                value (map get-by-id-helper-private value)
                (list)
            ))
        )
        (ok participants)
    )
)

;; Get Pot ID
(define-read-only (get-pot-id)
    (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots get-token-id pot-treasury-address)
)

;; Get Pot Starter Principal
(define-read-only (get-pot-starter-principal)
    (ok (var-get pot-starter-principal))
)

;; Get Pot Claimer Principal
(define-read-only (get-pot-claimer-principal)
    (ok (var-get pot-claimer-principal))
)

;; Get random digit from VRF and return the winner index
(define-private (get-random-index (participant-count uint))
    (let (
            ;; Get random digit from VRF
            ;; Get sender uint
            (sender-buff (unwrap! (to-consensus-buff? tx-sender) ERR_NOT_FOUND))
            (pot-admin-buff (unwrap! (to-consensus-buff? pot-admin) ERR_NOT_FOUND))
            (merged-buff (concat sender-buff pot-admin-buff))
            (merged-sha256 (sha256 merged-buff))
            (merged-sha256-uint (buff-to-uint-le (contract-call?
                'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-vrf
                lower-16-le merged-sha256
            )))
            (vrf-random-digit (unwrap! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-vrf get-random-uint-at-block stacks-block-height) ERR_NOT_FOUND))
        )        
        (ok (mod vrf-random-digit participant-count))
    )
)

;; Private helper function that delegates to pot-treasury
(define-private (delegate-to-pot (amount uint) (participant principal))
    (let 
        (
            (participants-stx-balance (stx-get-balance participant))
            (index-participants (var-get last-participant))
            (pot-config (get-configs))
            (max-participants (get max-participants pot-config))
            (min-amount (get min-amount pot-config))
        )
        ;; Participants Eligibility Validations
        (asserts! (>= amount min-amount) ERR_INSUFFICIENT_AMOUNT)

        (asserts! (not (is-eq participant pot-treasury-address)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq participant platform-address)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq participant pot-admin)) ERR_UNAUTHORIZED)

        (asserts! (<= index-participants max-participants)
            ERR_MAX_PARTICIPANTS_REACHED
        )
        (asserts!
            (not (is-some (map-get? pot-participants-by-principal participant)))
            ERR_DUPLICATE_PARTICIPANT
        )

        ;; Registers Participants Values To The Pot Maps
        (map-insert pot-participants-by-principal participant index-participants)
        (map-insert pot-participants-by-id index-participants {participant: participant, amount: amount})

        ;; Transfers User's Delegated Amount To Pot Treasury
        (asserts! (is-ok (stx-transfer-memo? amount participant pot-treasury-address (unwrap! (to-consensus-buff? "join pot") ERR_NOT_FOUND))) ERR_POT_JOIN_FAILED)

        ;; Updates Pot Value
        (add-pot-value amount)

        ;; Action Log
        (print {
            event: "delegate-to-pot",
            participant: participant,
            amount: amount,
            index: index-participants,
        })

        ;; Updates Last Participant To Next Pot Joiner
        (var-set last-participant (+ index-participants u1))

        ;; Execution Complete
        (ok true)
    )
)

;; Public Function That Initiates The Payments
(define-public (join-pot (amount uint) (participant principal))
    (begin

        ;; Validate can join pot
        ;; Validate amount is greater than 0
        ;; Validate participant is the same as the tx sender
        ;; Delegate to pot
        (asserts! (not (var-get locked)) ERR_POT_JOIN_CLOSED)
        (asserts! (> amount u0) ERR_INSUFFICIENT_AMOUNT)
        (asserts! (is-eq tx-sender participant) ERR_PARTICIPANT_ONLY)

        (asserts! (is-ok (delegate-to-pot amount participant)) ERR_DELEGATE_FAILED)

        (ok true)
    )
)

;; Public Function That Starts The Jackpot
(define-public (start-stackspot-jackpot (pot-contract <stackspot-trait>))
    (let ((pot-treasury (unwrap! (get-pot-treasury) ERR_NOT_FOUND)))

        ;; Validate can pool pot
        ;; Validate pot treasury is the same as the pot contract
        (asserts! (validate-can-pool-pot) ERR_POOL_ENTRY_PASSED)
        (asserts! (is-eq pot-treasury (contract-of pot-contract)) ERR_UNAUTHORIZED)

        ;; Delegate treasury to pot contract
        (asserts! (is-ok (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots delegate-treasury pot-contract pot-treasury))) ERR_DELEGATE_FAILED)

        ;; Set pot starter principal
        (var-set pot-starter-principal (some tx-sender))

        ;; Lock pot
        (var-set locked true)

        ;; Print
        (print {
            event: "start-stackspot-jackpot",
            pot-starter-principal: tx-sender,
            pot-contract: (contract-of pot-contract),
            pot-treasury: pot-treasury,
            pot-participants: (unwrap! (get-pot-participants) ERR_NOT_FOUND),
            pot-value: (var-get total-pot-value),
            pot-locked: (var-get locked),
        })

        ;; Execution complete
        (ok true)
    )
)

;; Public function that rewards the pot winner, returns participants principals and rewards pot starter and claimer
(define-public (claim-pot-reward (pot-contract <stackspot-trait>))
    (let 
        (
            ;; Get pot details
            (pot-details (unwrap! (get-pot-details) ERR_NOT_FOUND))
            ;; @value: pot ID
            ;; @value: pot winner's ID
            ;; @value: pot winner's {participant: principal, amount: uint}
            ;; @value: pot winner's principal
            ;; @value: pot winner's reward
            (pot-id (get pot-id pot-details))
            (total-participants (get pot-participants-count pot-details))

            (participants (get pot-participants pot-details)) ;; Get participants list            
            (stacked-reward (unwrap! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token get-balance pot-treasury-address) ERR_NOT_FOUND)) ;; Get stacked reward

            (pot-winner-id (unwrap! (get-random-index total-participants) ERR_NOT_FOUND))
            (winner-values (unwrap! (map-get? pot-participants-by-id pot-winner-id) ERR_NOT_FOUND))
            (winner (get participant winner-values))
            (winners-reward (* (/ stacked-reward u100) u90)) ;; Calculate winner's reward 99% of stacked reward or 100% of stacked reward   
                                    
            (pot-starter (get pot-starter-address pot-details))
            (pot-starter-reward (if (> stacked-reward u0) (* (/ stacked-reward u100) u2) u0));; Calculate pot starter's reward
            
            (claimer tx-sender) ;; Calculate claimer's reward
            (claimer-reward (if (> stacked-reward u0) (* (/ stacked-reward u100) u2) u0))
        )
        ;; Validate can claim pot
        (asserts! (validate-can-claim-pot) ERR_POT_CLAIM_NOT_REACHED)
        (asserts! (> stacked-reward u0) ERR_INSUFFICIENT_POT_REWARD)

        ;; Set pot claimer principal
        (var-set pot-claimer-principal (some tx-sender))

        ;; Set winners address
        (var-set winners-values (some {winner-id: pot-winner-id, winner-address: winner}))

        ;; Returns participants principals
        (asserts! (is-ok (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots dispatch-principals pot-contract))) ERR_DISPATCH_FAILED)

        ;; Disburse rewards
        (asserts! (is-ok (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots dispatch-rewards pot-contract))) ERR_DISPATCH_FAILED)

        ;; Print
        (print {
            ;; Pot Values
            event: "claim-pot-reward",
            ;; Pot Round Values
            pot-participants-count: total-participants, 
            pot-participants: participants,
            pot-value: (get pot-value pot-details),
            pot-yield-amount: stacked-reward,
            ;; Winner Values
            winners-values: (var-get winners-values),
            ;; Starter Values
            starter-address: pot-starter,
            starter-reward-amount: pot-starter-reward,
            ;; Claimer Values
            claimer-address: claimer,
            claimer-reward-amount: claimer-reward,
            ;; Pot Values
            pot-id: pot-id,
            pot-address: (get pot-address pot-details),
            pot-owner: (get pot-owner pot-details),
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
        })
        ;; Execution complete
        (ok true)
    )
)

;; Pot Deployer Configuration
(define-constant pot-cycle u1)
(define-constant pot-min-amount u100)
(define-constant pot-max-participants u100)
(define-constant pot-name "StackSpot Jackpot")
(define-constant pot-type "StackSpot Jackpot")
(define-constant origin-contract-sha-hash "5c15e5196a9c0afb580a242fbafd41cee6d4fcf5f196d3b2fdc92d7ca30e2bba")
;; Register pot
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots register-pot {owner: tx-sender, contract: (as-contract tx-sender), cycles: u1, type: pot-type, pot-reward-token: "sbtc", min-amount: u100, max-participants: u100, contract-sha-hash: origin-contract-sha-hash})

;; (define-public (register-pot) 
;;     (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots register-pot {owner: tx-sender, contract: (as-contract tx-sender), cycles: u1, type: pot-type, pot-reward-token: "sbtc", min-amount: u100, max-participants: u100, contract-sha-hash: origin-contract-sha-hash})
;; )