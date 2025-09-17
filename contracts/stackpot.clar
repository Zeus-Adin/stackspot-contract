(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pot-trait.stackpot-pot-trait)
(use-trait stackpot-pot-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pot-trait.stackpot-pot-trait)

(define-constant INSUFFICIENT_BALANCE (err u100))
(define-constant UNAUTHORIZED_PARTICIPANT (err u102))
(define-constant DELEGATE_LOCKED (err u103))
(define-constant NOT_FOUND (err u104))
(define-constant UNAUTHORIZED_POT_OWNER (err u105))
(define-constant MAX_PARTICIPANT_REACHED (err u107))
(define-constant INVALID_ARGUMENT (err u108))
(define-constant INSUFFICIENT_AMOUNT (err u109))
(define-constant DUPLICATE_PARTICIPANT (err u110))

;; Total max recipients
(define-constant total-max-recipients u100)

;; Platform address
(define-constant platform-address 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
;; Pot treasury address
(define-constant pot-treasury-address (as-contract tx-sender))
;; Pot owner
(define-data-var pot-owner principal tx-sender)
;; Pot starter
(define-data-var pot-starter-principal (optional principal) none)

;; Pot rounds counter
(define-data-var pot-rounds uint u0)

;; Pot participants maps
(define-map pot-participants-by-principal
  principal
  uint
)
(define-map pot-participants-by-id
  uint
  {
    participant: principal,
    amount: uint,
  }
)

;; Locking mechanism to prevent participants from joining the pot while the pot is running
(define-data-var locked bool false)
(define-read-only (is-locked)
  (var-get locked)
)

;; Last participant index in the pot-participants-by-id map
(define-data-var last-participant uint u0)
(define-read-only (get-last-participant)
  (var-get last-participant)
)

;; Reward token
(define-data-var reward-token (string-ascii 16) "stx")
(define-read-only (get-reward-token)
  (var-get reward-token)
)
(define-public (set-reward-token (new-reward-token (string-ascii 16)))
  (begin
    (asserts! (is-eq tx-sender (var-get pot-owner)) UNAUTHORIZED_POT_OWNER)
    (var-set reward-token new-reward-token)
    (ok true)
  )
)

;; Contract Config
(define-map config
  (string-ascii 16)
  uint
)
(define-read-only (get-configs)
  (let (
      (cycles (map-get? config "cycle"))
      (fee (map-get? config "pot-fee"))
      (max-participants (map-get? config "max"))
    )
    {
      cycles: cycles,
      fee: fee,
      max-participants: max-participants,
    }
  )
)
(define-public (set-config
    (config-key (string-ascii 10))
    (value uint)
  )
  (if (is-eq config-key "max-participants")
    (begin
      (asserts! (<= value total-max-recipients) INVALID_ARGUMENT)
      (asserts! (is-eq tx-sender (var-get pot-owner)) UNAUTHORIZED_POT_OWNER)
      (asserts! (is-some (map-get? config config-key)) NOT_FOUND)
      (ok (map-set config config-key value))
    )
    (begin
      (asserts! (not (is-eq config-key "")) INVALID_ARGUMENT)
      (asserts! (is-eq tx-sender (var-get pot-owner)) UNAUTHORIZED_POT_OWNER)
      (asserts! (is-some (map-get? config config-key)) NOT_FOUND)
      (ok (map-set config config-key value))
    )
  )
)

;; Pot Fee configuration function
(define-read-only (get-pot-fee)
  (map-get? config "pot-fee")
)
(define-public (set-pot-fee (new-fee uint))
  (begin
    (asserts! (> new-fee u0) INVALID_ARGUMENT)
    (asserts! (is-eq tx-sender (var-get pot-owner)) UNAUTHORIZED_POT_OWNER)
    (ok (map-set config "pot-fee" new-fee))
  )
)

;; Pot value configs in STX
(define-data-var total-pot-value uint u0)
(define-read-only (get-pot-value)
  (var-get total-pot-value)
)
(define-private (add-pot-value (amount uint))
  (var-set total-pot-value (+ (var-get total-pot-value) amount))
)
(define-private (remove-pot-value (amount uint))
  (var-set total-pot-value (- (var-get total-pot-value) amount))
)

;; Read-Only public function that gets participant by index
;; Read-Only public function that gets all participants
(define-read-only (get-by-id-helper (n uint))
  (map-get? pot-participants-by-id n)
)
(define-read-only (get-pot-participants)
  (let (
      (n (get-list (var-get last-participant)))
      (participants (match n
        value (map get-by-id-helper value)
        (list)
      ))
    )
    (ok participants)
  )
)

;; Private function that pays fees to platform and pot owner
;; Private helper function that delegates to pot-treasury
;; Public function that initiates the payment's
(define-private (pay-fees (amount uint))
  (begin
    (try! (stx-transfer-memo? (* (/ amount u100) u10) tx-sender platform-address
      (unwrap! (to-consensus-buff? "platform-fee") NOT_FOUND)
    ))
    (try! (stx-transfer-memo? (* (/ amount u100) u90) tx-sender (var-get pot-owner)
      (unwrap! (to-consensus-buff? "pot-fee") NOT_FOUND)
    ))
    (ok true)
  )
)
(define-private (delegate-to-pot
    (amount uint)
    (participant principal)
  )
  (let (
      (participants-stx-balance (stx-get-balance participant))
      (index-participants (var-get last-participant))
      (max-participants (unwrap! (map-get? config "max-participants") NOT_FOUND))
      (min-amount (unwrap! (map-get? config "min-amount") NOT_FOUND))
      (pot-fee (unwrap! (map-get? config "pot-fee") NOT_FOUND))
    )
    ;; Participants eligibility validations
    (asserts! (not (var-get locked)) DELEGATE_LOCKED)
    (asserts! (>= amount min-amount) INSUFFICIENT_AMOUNT)
    (asserts! (>= participants-stx-balance (+ amount pot-fee))
      INSUFFICIENT_BALANCE
    )

    (asserts! (not (is-eq participant pot-treasury-address))
      UNAUTHORIZED_PARTICIPANT
    )
    (asserts! (not (is-eq participant platform-address)) UNAUTHORIZED_PARTICIPANT)
    (asserts! (not (is-eq participant (var-get pot-owner)))
      UNAUTHORIZED_PARTICIPANT
    )

    (asserts! (<= index-participants max-participants) MAX_PARTICIPANT_REACHED)
    (asserts!
      (not (is-some (map-get? pot-participants-by-principal participant)))
      DUPLICATE_PARTICIPANT
    )

    ;; Registers participants values to the pot maps
    (map-insert pot-participants-by-principal participant amount)
    (map-insert pot-participants-by-id index-participants {
      participant: participant,
      amount: amount,
    })

    ;; Transfers pot fee to pot owner
    (try! (pay-fees pot-fee))

    ;; Transfers user's delegated amount to pot-treasury
    (try! (stx-transfer-memo? amount participant pot-treasury-address
      (unwrap! (to-consensus-buff? "joined pot") NOT_FOUND)
    ))

    ;; Updates pot value
    (add-pot-value amount)

    ;; Action log
    (print {
      event: "delegate-to-pot",
      participant: participant,
      amount: amount,
      index: index-participants,
    })

    ;; Updates last-participant to next pot-joiner
    (var-set last-participant (+ index-participants u1))

    (if (is-eq index-participants max-participants)
      (begin
        (try! (start-jackpot))
        true
      )
      false
    )

    ;; Execution complete
    (ok true)
  )
)
(define-public (join-pot
    (amount uint)
    (participant principal)
  )
  (begin
    (asserts! (> amount u0) INSUFFICIENT_AMOUNT)
    (asserts! (is-eq tx-sender participant) UNAUTHORIZED_PARTICIPANT)
    (try! (delegate-to-pot amount participant))
    (ok true)
  )
)

(define-public (start-jackpot)
  (let ((pot-id (unwrap!
      (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pots
        get-pot-info pot-treasury-address
      )
      NOT_FOUND
    )))
    (var-set pot-starter-principal (some tx-sender))
    (ok true)
  )
)

;; Private helper function that returns participant principals
(define-private (return-participant-principals
    (participant-value (optional {
      participant: principal,
      amount: uint,
    }))
    (res (response bool uint))
  )
  (let (
      (participant (unwrap! (get participant participant-value) NOT_FOUND))
      (principal-amount (unwrap! (get amount participant-value) NOT_FOUND))
    )
    (try! (stx-transfer-memo? principal-amount pot-treasury-address participant
      (unwrap! (to-consensus-buff? "participant principal") NOT_FOUND)
    ))
    res
  )
)

;; Public function that rewards the pot winner, returns participants principals and rewards pot starter and claimer
(define-public (claim-pot-reward (pot-contract <stackpot-pot-trait>))
  (let (
      ;; Get pot ID
      (pot-id (unwrap!
        (unwrap!
          (contract-call?
            'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pots
            get-token-id pot-treasury-address
          )
          NOT_FOUND
        )
        NOT_FOUND
      ))
      ;; Get 
      ;; @value: pot winner's ID
      ;; @value: pot winner's values
      ;; @value: pot winner's principal
      (total-participants (var-get last-participant))
      (pot-winner-id (unwrap! (get-random-index total-participants) NOT_FOUND))
      (winner-values (unwrap! (map-get? pot-participants-by-id pot-winner-id) NOT_FOUND))
      (winner (get participant winner-values))
      ;; Get participants list
      (participants (get-pot-participants))
      ;;;;  Get stacked reward
      (stacked-reward (- (stx-get-balance pot-treasury-address) (var-get total-pot-value)))
      ;;;;  Calculate pot starter's reward
      (pot-starter (unwrap! (var-get pot-starter-principal) NOT_FOUND))
      (pot-starter-reward (if (> stacked-reward u0)
        (* (/ stacked-reward u100) u5)
        u0
      ))
      ;;;;  Calculate claimer's reward
      (claimer tx-sender)
      (claimer-reward (if (> stacked-reward u0)
        (* (/ stacked-reward u100) u5)
        u0
      ))
      ;; Calculate winner's reward 99% of stacked reward or 100% of stacked reward
      (winners-reward (- stacked-reward (+ pot-starter-reward claimer-reward)))
      ;;;;  Update pot rounds
      (new-round (+ (var-get pot-rounds) u1))
    )
    ;; Returns participants principals
    (try! (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pots
      claiming-pot-reward-return-principals pot-id pot-contract
    )))

    ;;;;  Tips 5% of stacked return to pot starter
    ;;;;  Tips 5% of stacked return to claimer
    ;; (try! (stx-transfer-memo? pot-starter-reward pot-treasury-address pot-starter (unwrap! (to-consensus-buff? "started pot") NOT_FOUND)))
    ;; (try! (stx-transfer-memo? claimer-reward pot-treasury-address claimer (unwrap! (to-consensus-buff? "claimed pot") NOT_FOUND)))

    ;;;;  Pay winner
    ;; (try! (stx-transfer-memo? winners-reward pot-treasury-address winner (unwrap! (to-consensus-buff? "pot winner") NOT_FOUND)))

    ;;
    (is-ok (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pots
      log-winner {
      ;; Pot Values
      pot-id: pot-id,
      pot-owner: (var-get pot-owner),
      pot-round: (var-get pot-rounds),
      pot-participants: (var-get last-participant),
      pot-value: (var-get total-pot-value),
      ;; Pot Config Values
      pot-cycle: (unwrap! (map-get? config "cycle") NOT_FOUND),
      pot-reward-token: (var-get reward-token),
      pot-fee: (unwrap! (map-get? config "pot-fee") NOT_FOUND),
      pot-min-amount: (unwrap! (map-get? config "min-amount") NOT_FOUND),
      pot-max-participants: (unwrap! (map-get? config "max-participants") NOT_FOUND),
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

    (print {
      ;; Pot Values
      pot-id: pot-id,
      pot-owner: (var-get pot-owner),
      pot-round: (var-get pot-rounds),
      pot-participants: (var-get last-participant),
      pot-value: (var-get total-pot-value),
      ;; Pot Config Values
      pot-cycle: (unwrap! (map-get? config "cycle") NOT_FOUND),
      pot-reward-token: (var-get reward-token),
      pot-fee: (unwrap! (map-get? config "pot-fee") NOT_FOUND),
      pot-min-amount: (unwrap! (map-get? config "min-amount") NOT_FOUND),
      pot-max-participants: (unwrap! (map-get? config "max-participants") NOT_FOUND),
      ;; Winner Values
      winner-id: pot-winner-id,
      winner-address: winner,
      winner-amount: winners-reward,
      winner-values: winner-values,
      winner-timestamp: {
        stacks-block-height: stacks-block-height,
        burn-block-height: burn-block-height,
      },
    })

    ;;;;  Reset all pot values
    (var-set total-pot-value u0)
    (var-set last-participant u0)
    (var-set pot-rounds new-round)
    (var-set pot-starter-principal none)

    ;; (map-delete pot-participants-by-principal (unwrap! (map-get? pot-participants-by-principal winner) NOT_FOUND))
    ;; (map-delete pot-participants-by-id pot-winner-id)

    ;; (map is-locked sequence)

    (ok true)
  )
)

;; Get random digit from VRF and return the winner index
(define-private (get-random-index (participant-count uint))
  (let (
      ;; Get random digit from VRF
      ;; Get sender uint
      (sender-buff (unwrap! (to-consensus-buff? tx-sender) NOT_FOUND))
      (pot-owner-buff (unwrap! (to-consensus-buff? (var-get pot-owner)) NOT_FOUND))
      (merged-buff (concat sender-buff pot-owner-buff))
      (merged-sha256 (sha256 merged-buff))
      (merged-sha256-uint (buff-to-uint-le (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-vrf
        lower-16-le merged-sha256
      )))
      (vrf-random-digit (unwrap!
        (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-vrf
          get-random-uint-at-block stacks-block-height
        )
        NOT_FOUND
      ))
    )
    (print {
      vrf-random-digit: vrf-random-digit,
      merged-sha256-uint: merged-sha256-uint,
      participant-count: participant-count,
    })
    (ok (mod vrf-random-digit participant-count))
  )
)
;; Get list of participants
(define-read-only (get-list (length uint))
  (slice?
    (list
      u0       u1       u2       u3       u4       u5       u6       u7       u8
      u9       u10       u11       u12       u13       u14       u15       u16
      u17       u18       u19       u20       u21       u22       u23       u24
      u25       u26       u27       u28       u29       u30       u31       u32
      u33       u34       u35
      u36       u37       u38
      u39       u40       u41       u42       u43       u44       u45       u46
      u47       u48       u49       u50       u51       u52       u53       u54
      u55       u56       u57
      u58       u59       u60       u61       u62       u63       u64       u65
      u66       u67       u68       u69       u70       u71       u72       u73
      u74       u75       u76
      u77       u78       u79       u80       u81       u82       u83       u84
      u85       u86       u87       u88       u89       u90       u91       u92
      u93       u94       u95
      u96       u97       u98       u99
    )
    u0 length
  )
)

;; Initialize config
(var-set reward-token "sbtc")
(map-insert config "cycle" u1)
(map-insert config "pot-fee" u100000)
(map-insert config "min-amount" u100)
(map-insert config "max-participants" u100)

;; Register pot
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackpot-pots
  register-pot {
  owner: tx-sender,
  contract: (as-contract tx-sender),
})
