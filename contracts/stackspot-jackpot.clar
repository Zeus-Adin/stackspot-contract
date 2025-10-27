;; (impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)
(use-trait stackspot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-trait.stackspot-trait)

;; --- Not Found
(define-constant ERR_NOT_FOUND (err u1001))

;; --- Authorization
(define-constant ERR_UNAUTHORIZED (err u1101))
(define-constant ERR_ADMIN_ONLY (err u1102))
(define-constant ERR_PARTICIPANT_ONLY (err u1103))
(define-constant ERR_DUPLICATE_PARTICIPANT (err u1104))

;; --- Validation / Input
(define-constant ERR_INVALID_ADDRESS (err u1201))
(define-constant ERR_INVALID_ARGUMENT_VALUE (err u1202))
(define-constant ERR_INVALID_POT (err u1203))

;; --- Balance / Funds
(define-constant ERR_INSUFFICIENT_BALANCE (err u1301))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u1302))
(define-constant ERR_INSUFFICIENT_POT_BALANCE (err u1303))

;; --- Pot Lifecycle
(define-constant ERR_POT_JOIN_CLOSED (err u1401))
(define-constant ERR_POT_CLAIM_NOT_REACHED (err u1402))
(define-constant ERR_POOL_ENTRY_PASSED (err u1403))
(define-constant ERR_POT_ALREADY_STARTED (err u1404))
(define-constant ERR_MAX_PARTICIPANTS_REACHED (err u1405))

;; Total Max Participants
(define-constant total-max-participants u100)

;; Platform Address
(define-constant platform-address 'STNHKEPYEPJ8ET55ZZ0M5A34J0R3N5FM2CMMMAZ6)
;; Pot Treasury Address
(define-constant pot-treasury-address (as-contract tx-sender))
;; Pot Admin
(define-data-var pot-admin principal tx-sender)


;; Pot Starter Principal
(define-data-var pot-starter-principal (optional principal) none)
;; Pot Claimer Principal
(define-data-var pot-claimer-principal (optional principal) none)

;; Pot Rounds Counter
(define-data-var pot-rounds uint u0)

;; Pot Participants Maps
(define-map pot-participants-by-principal principal uint)
(define-map pot-participants-by-id uint {participant: principal, amount: uint})

;; Get PoX Info and return pool config
(define-read-only (get-pox-info) (unwrap-panic (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sim-pox get-pox-info)))
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

;; Pot Join Start validation
(define-read-only (validate-can-join-pot) 
    (var-get locked)
)

;; Pot Claim Start validation
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

;; Locking Mechanism To Prevent Participants From Trying To Join The Pot While The Pot Is Stacked In Pool
(define-data-var locked bool false)
(define-read-only (is-locked) (var-get locked))

;; Last Participant Indexed In The Pot Participants By Id Map
(define-data-var last-participant uint u0)
(define-read-only (get-last-participant) (ok (var-get last-participant)))

;; Contract Config
(define-map config (string-ascii 16) uint)
(define-read-only (get-configs)
    (let (
            (cycles (map-get? config "cycle"))
            (fee (map-get? config "pot-fee"))
            (max-participants (map-get? config "max-participants"))
        )
        { cycles: cycles, pot-fee: fee, max-participants: max-participants }
    )
)
(define-public (set-config (config-key (string-ascii 10)) (value uint))
    (if (is-eq config-key "max-participants")
        (begin
            (asserts! (> value total-max-participants) ERR_INVALID_ARGUMENT_VALUE)
            (asserts! (is-eq tx-sender (var-get pot-admin)) ERR_ADMIN_ONLY)
            (ok (map-set config config-key value))
        )
        (begin
            (asserts! (not (is-eq config-key "")) ERR_INVALID_ARGUMENT_VALUE)
            (asserts! (is-eq tx-sender (var-get pot-admin)) ERR_ADMIN_ONLY)
            (ok (map-set config config-key value))
        )
    )
)

;; Reward token
(define-data-var reward-token (string-ascii 16) "stx")
(define-read-only (get-reward-token) (var-get reward-token))

;; Pot Value
(define-data-var total-pot-value uint u0)
(define-read-only (get-pot-value) (var-get total-pot-value))

;; Increment Pot Value
(define-private (add-pot-value (amount uint))
    (var-set total-pot-value (+ (var-get total-pot-value) amount))
)
;; Decrement Pot Value
(define-private (remove-pot-value (amount uint))
    (var-set total-pot-value (- (var-get total-pot-value) amount))
)

;; Get List By Length
(define-read-only (get-list (length uint)) (slice? (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60 u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80 u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99) u0 length))

;; Read-Only public function that gets participant by index
(define-read-only (get-by-id-helper (n uint)) (ok (map-get? pot-participants-by-id n)))

;; Read-Only public function that gets all participants
(define-read-only (get-pot-participants)
    (let 
        (
            (n (get-list (var-get last-participant)))
            (participants (match n value (map get-by-id-helper value) (list)))
        )
        (ok participants)
    )
)
;; Get Pot Treasury
(define-read-only (get-pot-treasury)
    pot-treasury-address
)
;; Get Pot ID
(define-read-only (get-pot-id)
    (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots get-token-id pot-treasury-address)
)

;; Get Pot Starter Principal
(define-read-only (get-pot-starter-principal)
    (var-get pot-starter-principal)
)
;; Get Pot Claimer Principal
(define-read-only (get-pot-claimer-principal)
    (var-get pot-claimer-principal)
)

;; Private Function That Pays Fees To Platform And Pot Owner
(define-private (pay-fees (amount uint))
    (begin
        (try! (stx-transfer-memo? (* (/ amount u100) u10) tx-sender platform-address (unwrap! (to-consensus-buff? "platform-fee") ERR_NOT_FOUND)))
        (try! (stx-transfer-memo? (* (/ amount u100) u90) tx-sender (var-get pot-admin) (unwrap! (to-consensus-buff? "pot-fee") ERR_NOT_FOUND)))
        (ok true)
    )
)

;; Private helper function that delegates to pot-treasury
(define-private (delegate-to-pot
        (amount uint)
        (participant principal)
    )
    (let (
            (participants-stx-balance (stx-get-balance participant))
            (index-participants (var-get last-participant))
            (max-participants (unwrap! (map-get? config "max-participants") ERR_NOT_FOUND))
            (min-amount (unwrap! (map-get? config "min-amount") ERR_NOT_FOUND))
            (pot-fee (unwrap! (map-get? config "pot-fee") ERR_NOT_FOUND))
        )
        ;; Participants Eligibility Validations
        (asserts! (>= amount min-amount) ERR_INSUFFICIENT_AMOUNT)
        (asserts! (>= participants-stx-balance (+ amount pot-fee)) ERR_INSUFFICIENT_BALANCE)

        (asserts! (not (is-eq participant pot-treasury-address)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq participant platform-address)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq participant (var-get pot-admin))) ERR_UNAUTHORIZED)

        (asserts! (<= index-participants max-participants) ERR_MAX_PARTICIPANTS_REACHED)
        (asserts! (not (is-some (map-get? pot-participants-by-principal participant))) ERR_DUPLICATE_PARTICIPANT)

        ;; Registers Participants Values To The Pot Maps
        (map-insert pot-participants-by-principal participant amount)
        (map-insert pot-participants-by-id index-participants {participant: participant, amount: amount})

        ;; Transfers Pot Fee To Pot Admin and Platform
        (try! (pay-fees pot-fee))

        ;; Transfers User's Delegated Amount To Pot Treasury
        (try! (stx-transfer-memo? amount participant pot-treasury-address (unwrap! (to-consensus-buff? "join pot") ERR_NOT_FOUND)))

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
(define-public (join-pot
        (amount uint)
        (participant principal)
    )
    (begin
        ;; Validate can join pot
        (asserts! (validate-can-join-pot) ERR_POT_JOIN_CLOSED)
        ;; Validate amount is greater than 0
        (asserts! (> amount u0) ERR_INSUFFICIENT_AMOUNT)
        ;; Validate participant is the same as the tx sender
        (asserts! (is-eq tx-sender participant) ERR_PARTICIPANT_ONLY)
        ;; Delegate to pot
        (try! (delegate-to-pot amount participant))
        (ok true)
    )
)

;; Public Function that withdraws the participant's amount from the pot
(define-public (withdraw-from-pot (pot-contract <stackspot-trait>))
    (let ((participant-index (unwrap! (map-get? pot-participants-by-principal tx-sender) ERR_NOT_FOUND))) 
        (asserts! (not (var-get locked)) ERR_POT_ALREADY_STARTED)

        (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots withdraw-from-pot participant-index pot-contract))
        (ok true)
    )
)

;; Public Function That Starts The Jackpot
(define-public (start-stackspot-jackpot (pot-contract <stackspot-trait>))
    (let
        ((pot-treasury (get-pot-treasury)))

        ;; Validate pot is not locked
        (asserts! (validate-can-join-pot) ERR_POT_JOIN_CLOSED)

        ;; Validate can pool pot
        (asserts! (validate-can-pool-pot) ERR_POOL_ENTRY_PASSED)

        ;; Validate pot treasury is the same as the pot contract
        (asserts! (is-eq pot-treasury (contract-of pot-contract)) ERR_UNAUTHORIZED)

        ;; Delegate treasury to pot contract
        (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots delegate-treasury pot-contract (contract-of pot-contract)))

        ;; Set pot starter principal
        (var-set pot-starter-principal (some tx-sender))

        ;; Lock pot
        (var-set locked true)

        ;; Print
        (print {
            event: "start-stackspot-jackpot",
            pot-starter-principal: tx-sender,
            port-claim-principal: (var-get pot-claimer-principal),
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
            ;; Get pot ID
            (pot-id (unwrap! (unwrap! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots get-token-id pot-treasury-address) ERR_NOT_FOUND) ERR_NOT_FOUND))
            ;; Get 
            ;; @value: pot winner's ID
            ;; @value: pot winner's values
            ;; @value: pot winner's principal
            (total-participants (var-get last-participant))
            (pot-winner-id (unwrap! (get-random-index total-participants) ERR_NOT_FOUND))
            (winner-values (unwrap! (map-get? pot-participants-by-id pot-winner-id) ERR_NOT_FOUND))
            (winner (get participant winner-values))

            ;; Get participants list
            (participants (get-pot-participants))

            ;; Get stacked reward
            (stacked-reward (- (stx-get-balance pot-treasury-address) (var-get total-pot-value)))

            ;; Calculate pot starter's reward
            (pot-starter (unwrap! (var-get pot-starter-principal) ERR_NOT_FOUND))
            (pot-starter-reward (if (> stacked-reward u0) (* (/ stacked-reward u100) u5) u0))

            ;; ;; Calculate claimer's reward
            (claimer tx-sender)
            (claimer-reward (if (> stacked-reward u0) (* (/ stacked-reward u100) u5) u0))

            ;; Calculate winner's reward 99% of stacked reward or 100% of stacked reward
            (winners-reward (- stacked-reward (+ pot-starter-reward claimer-reward)))
            ;; Update pot rounds
            (new-round (+ (var-get pot-rounds) u1))
        )

        ;; Validate can claim pot
        (asserts! (validate-can-claim-pot) ERR_POT_CLAIM_NOT_REACHED)

        ;; Returns participants principals
        (try! (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots dispatch-principals pot-contract)))       

        ;; Pay winner
        (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots dispatch-rewards winner-values pot-contract))

        ;; Log winner
        (is-ok (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots log-winner {
            ;; Pot Values
            pot-id: pot-id,
            pot-admin: (var-get pot-admin),
            pot-round: (var-get pot-rounds),
            pot-participants: (var-get last-participant),
            pot-value: (var-get total-pot-value),
            ;; Pot Config Values
            pot-cycle: (unwrap! (map-get? config "cycle") ERR_NOT_FOUND),
            pot-reward-token: (var-get reward-token),
            pot-fee: (unwrap! (map-get? config "pot-fee") ERR_NOT_FOUND),
            pot-min-amount: (unwrap! (map-get? config "min-amount") ERR_NOT_FOUND),
            pot-max-participants: (unwrap! (map-get? config "max-participants") ERR_NOT_FOUND),
            
            ;; Pot Starter Values
            pot-starter-address: pot-starter,
            pot-starter-amount: pot-starter-reward,
            ;; Claimer Values
            claimer-address: claimer,
            claimer-amount: claimer-reward,
            
            ;; Winner Values
            winner-id: pot-winner-id,
            winner-address: winner,
            winner-amount: winners-reward,
            winner-values: winner-values,
            winner-timestamp: {
                stacks-block-height: stacks-block-height,
                burn-block-height: burn-block-height,
            },
        }))

        ;; Print
        (print
            {
            ;; Pot Values
            event: "claim-pot-reward",
            pot-id: pot-id,
            pot-admin: (var-get pot-admin),
            pot-round: (var-get pot-rounds),
            pot-participants: (var-get last-participant),
            pot-value: (var-get total-pot-value),
            ;; Pot Config Values
            pot-cycle: (unwrap! (map-get? config "cycle") ERR_NOT_FOUND),
            pot-reward-token: (var-get reward-token),
            pot-fee: (unwrap! (map-get? config "pot-fee") ERR_NOT_FOUND),
            pot-min-amount: (unwrap! (map-get? config "min-amount") ERR_NOT_FOUND),
            pot-max-participants: (unwrap! (map-get? config "max-participants") ERR_NOT_FOUND),
            ;; Pot Starter Values
            pot-starter-address: pot-starter,
            pot-starter-amount: pot-starter-reward,
            ;; Claimer Values
            claimer-address: claimer,
            claimer-amount: claimer-reward,
            ;; Winner Values
            winner-id: pot-winner-id,
            winner-address: winner,
            winner-amount: winners-reward,
            winner-values: winner-values,
            winner-timestamp: {
                stacks-block-height: stacks-block-height,
                burn-block-height: burn-block-height,
            }
        })

        (ok true)
    )
)

;; Initialize config
(var-set reward-token "sbtc")
(map-insert config "cycle" u1)
(map-insert config "pot-fee" u100000)
(map-insert config "min-amount" u100)
(map-insert config "max-participants" u100)

;; Register pot
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspots register-pot {owner: tx-sender, contract: (as-contract tx-sender)})

;; Get random digit from VRF and return the winner index
(define-private (get-random-index (participant-count uint))
    (let (
            ;; Get random digit from VRF
            ;; Get sender uint
            (sender-buff (unwrap! (to-consensus-buff? tx-sender) ERR_NOT_FOUND))
            (pot-admin-buff (unwrap! (to-consensus-buff? (var-get pot-admin)) ERR_NOT_FOUND))
            (merged-buff (concat sender-buff pot-admin-buff))
            (merged-sha256 (sha256 merged-buff))
            (merged-sha256-uint (buff-to-uint-le (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-vrf lower-16-le merged-sha256)))
            (vrf-random-digit (unwrap! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-vrf get-random-uint-at-block stacks-block-height ) ERR_NOT_FOUND))
        )
        (print {
            vrf-random-digit: vrf-random-digit,
            merged-sha256-uint: merged-sha256-uint,
            participant-count: participant-count,
        })
        (ok (mod vrf-random-digit participant-count))
    )
)