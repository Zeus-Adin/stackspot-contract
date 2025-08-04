(define-constant INSUFFICIENT_BALANCE (err u100))
(define-constant UNAUTHORIZED_PARTICIPANT (err u102))
(define-constant DELEGATE_LOCKED (err u103))
(define-constant NOT_FOUND (err u104))
(define-constant UNAUTHORIZED_POT_OWNER (err u105))

(define-constant platform-address 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant pot-treasury-address (as-contract tx-sender))

(define-data-var pot-owner principal tx-sender)
(define-data-var locked bool false)
(define-data-var last-participant uint u0)
;; This value will be the winners index in the pot-participants-by-id map
(define-data-var pot-winner uint u0)

;; Contract Config
(define-map config (string-ascii 10) uint)
(define-read-only (get-config (config-key (string-ascii 10))) 
    (map-get? config config-key)
)
(define-public (set-config (config-key (string-ascii 10)) (value uint)) 
    (begin 
        (asserts! (is-eq tx-sender (var-get pot-owner)) UNAUTHORIZED_POT_OWNER)
        (asserts! (is-some (map-get? config config-key)) NOT_FOUND)
        (ok (map-set config config-key value))
    )
)

;; Pot Fee configuration function
(define-read-only (get-pot-fee) 
    (map-get? config "pot-fee")
)
(define-public (set-pot-fee (new-fee uint)) 
    (begin 
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

;; Pot participants maps
(define-map pot-participants-by-principal principal uint)
(define-map pot-participants-by-id uint {participant: principal, amount: uint})

(define-read-only (get-by-id-helper (n uint)) 
    (map-get? pot-participants-by-id n)
)
(define-read-only (get-pot-participants)
    (let 
        (
            (n (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 
                u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 
                u59 u60 u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80 u81 u82 u83 u84 u85 u86 u87 
                u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99
                )
            )
            (participants (slice? (map get-by-id-helper n) u0 (var-get last-participant)))
        ) 
        participants
    )
)

(define-private (delegate-to-pot (amount uint) (participant principal))
    (let (
            (participants-stx-balance (stx-get-balance participant))
            (index-participants (+ (var-get last-participant) u1))
        )
                 ;; Participants eligibility validations
        (asserts! (not (var-get locked)) DELEGATE_LOCKED)
        (asserts! (>= participants-stx-balance amount) INSUFFICIENT_BALANCE)
        (asserts! (is-eq tx-sender participant) UNAUTHORIZED_PARTICIPANT)

                 ;; Registers participants values to the pot maps
        (map-insert pot-participants-by-principal participant amount)
        (map-insert pot-participants-by-id index-participants {
            participant: participant,
            amount: amount,
        })

                 ;; Transfers user's delegated amount to pot-treasury
        (try! (stx-transfer-memo? amount participant pot-treasury-address (unwrap! (to-consensus-buff? "joined jot") NOT_FOUND)))

                 ;; Updates last-participant to recent pot-joiner
        (var-set last-participant index-participants)

        ;; Execution complete
        (ok true)
    )
)

(define-public (join-pot (amount uint) (participant principal))
    (ok true)
)

(define-public (start-jackpot)
    (ok true)
)

(define-private (return-participant-principals (participant-value (optional {participant: principal, amount: uint})) (res (response bool uint))) 
    (let 
        (
            (participant (unwrap! (get participant participant-value) NOT_FOUND))
            (principal-amount (unwrap! (get amount participant-value) NOT_FOUND))
        ) 
        (try! (stx-transfer-memo? principal-amount pot-treasury-address participant (unwrap! (to-consensus-buff? "participant principal") NOT_FOUND)))
        res
    )
)

(define-public (claim-pot-reward)
    (let 
        (
            (winner-values (map-get? pot-participants-by-id (var-get pot-winner)))
            (winner (unwrap! (get participant winner-values) NOT_FOUND))
            (participants (get-pot-participants))
            (stacked-reward u50)
            (claimer tx-sender)
            (claimer-reward (if (is-eq tx-sender winner) u0 (* (/ stacked-reward u100) u1)))
            (winners-reward (- stacked-reward claimer-reward))
        ) 
                 ;; Returns participants principals
        (if (is-some participants)
            (try! (fold return-participant-principals (unwrap! participants NOT_FOUND) (ok true)))
            false
        )

                 ;; Tips 1% of stacked return to claimer when claimer not winner
        (if (> claimer-reward u0) 
            (try! (stx-transfer-memo? claimer-reward pot-treasury-address claimer (unwrap! (to-consensus-buff? "claimed for winner") NOT_FOUND)))
            false
        )

                 ;; Pay winner
        (try! (stx-transfer-memo? winners-reward pot-treasury-address winner (unwrap! (to-consensus-buff? "pot winner") NOT_FOUND)))

        (ok true)
    )
)

(define-read-only (get-random-uint-at-block (max int))
    (let 
        (
        (vrf-lower-uint-opt
            (unwrap! (match (get-burn-block-info? header-hash stacks-block-height)
                header-hash (some (buff-to-uint-le (lower-16-le header-hash)))
                none
            ) NOT_FOUND)
        )
        (rand-num (mod (to-int vrf-lower-uint-opt) 0))
  )
  (ok {event:"get-random-uint-at-block", blockHeight: stacks-block-height, hash: vrf-lower-uint-opt, rand-num: rand-num})
  )
)
;; ;; Convert the lower 16 bytes of a buff into a little-endian uint.
(define-private (lower-16-le (input (buff 32)))
  (get acc
    (fold lower-16-le-closure (list u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31) { acc: 0x, data: input })
  )
)
;; ;; Inner closure for obtaining the lower 16 bytes of a 32-byte buff
(define-private (lower-16-le-closure (idx uint) (input { acc: (buff 16), data: (buff 32) }))
  (let (
    (acc (get acc input))
    (data (get data input))
    (byte (unwrap-panic (element-at data idx)))
  )
  (print {
    acc: (unwrap-panic (as-max-len? (concat acc byte) u16)),
    data: data
  })
  {
    acc: (unwrap-panic (as-max-len? (concat acc byte) u16)),
    data: data
  })
)




(map-insert config "min" u2)
(map-insert config "max" u100)
(map-insert config "cycle" u1)
(map-insert config "pot-fee" u100000)