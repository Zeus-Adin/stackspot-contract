(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait stackpot-pot-trait .stackpot-pot-trait.stackpot-pot-trait)

;; Core errors
(define-constant UNAUTHORIZED_POT_OWNER (err u108))
(define-constant NOT_FOUND (err u109))
(define-constant INSUFFICIENT_BALANCE (err u110))

;; Platform address
(define-constant platform-treasury tx-sender)

;; NFT Declaration
(define-non-fungible-token stackpot-pot uint)
(define-map token-owner-ids
    principal
    uint
)

;; NFT variables
(define-data-var last-token-id uint u0)

;; NFT errors
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-owner-not-permitted (err u102))
(define-constant err-not-permitted (err u103))

;; Core actions
(define-data-var fee uint u0)
(define-public (update-fee (newfee uint))
    (begin
        (asserts! (is-eq tx-sender platform-treasury) UNAUTHORIZED_POT_OWNER)
        (ok (var-set fee newfee))
    )
)
(define-read-only (get-fee)
    (var-get fee)
)

(define-public (register-pot (pot-values {
    owner: principal,
    contract: principal,
}))
    (let (
            (owner (get owner pot-values))
            (contract-address (get contract pot-values))
            (contract-info (unwrap! (principal-destruct? contract-address) NOT_FOUND))
            (contract-name (get name contract-info))
            (contract-version (get version contract-info))
            (contract-hash-bytes (get hash-bytes contract-info))
            (new-pot-owner-balance (stx-get-balance owner))
            (platform-contracts-fee (var-get fee))
        )
        (asserts! (> new-pot-owner-balance platform-contracts-fee)
            INSUFFICIENT_BALANCE
        )

        ;; Mint NFT
        (try! (mint contract-address))

        ;; Print event
        (print {
            event: "pot registered",
            nft-id: (+ (var-get last-token-id) u1),
            owner: owner,
            contract-address: contract-address,
            contract-name: contract-name,
            contract-version: contract-version,
            contract-hash-bytes: contract-hash-bytes,
            platform-contracts-fee: platform-contracts-fee,
        })

        (ok true)
    )
)

(define-public (log-winner (winner-values {
    ;; Pot Values
    pot-id: uint,
    pot-owner: principal,
    pot-round: uint,
    pot-participants: uint,
    pot-value: uint,
    ;; Pot Config Values
    pot-cycle: uint,
    pot-reward-token: (string-ascii 16),
    pot-fee: uint,
    pot-min-amount: uint,
    pot-max-participants: uint,
    ;; Winner Values
    winner-id: uint,
    winner-address: principal,
    winner-amount: uint,
    winner-values: {
        amount: uint,
        participant: principal,
    },
    winner-timestamp: {
        stacks-block-height: uint,
        burn-block-height: uint,
    }
}))
    (let (
            (pot-id (get pot-id winner-values))
            (pot-address (unwrap! (nft-get-owner? stackpot-pot pot-id) NOT_FOUND))
        )
        (asserts! (is-eq pot-address contract-caller) err-not-permitted)
        (ok (contract-call? .stackpot-pot-winners log-winner winner-values))
    )
)

(define-public (log-participant (participant-values {
    pot-id: uint,
    participant-id: uint,
    participant-address: principal,
    participant-amount: uint,
    participant-timestamp: uint,
}))
    (let (
            (pot-id (get pot-id participant-values))
            (pot-address (unwrap! (nft-get-owner? stackpot-pot pot-id) NOT_FOUND))
        )
        (asserts! (is-eq pot-address contract-caller) err-not-permitted)
        (is-ok (contract-call? .stackpot-pot-participants log-participant participant-values))
        (ok true)
    )
)

;; NFT actions
;; TODO: Implement get-token-uri and get-owner
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? stackpot-pot token-id))
)

(define-read-only (get-owner-token-id (owner principal))
    (map-get? token-owner-ids owner)
)

(define-read-only (get-token-id (owner principal))
    (ok (nft-get-owner? stackpot-pot (unwrap! (get-owner-token-id owner) NOT_FOUND)))
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? stackpot-pot token-id sender recipient)
    )
)

(define-public (mint (recipient principal))
    (let (
            (token-id (+ (var-get last-token-id) u1))
            (platform-contracts-fee (var-get fee))
        )
        (asserts! (is-eq tx-sender recipient) err-not-permitted)
        (asserts! (not (is-eq tx-sender platform-treasury))
            err-owner-not-permitted
        )
        (asserts! (not (is-eq platform-treasury recipient))
            err-owner-not-permitted
        )

        ;; Transfer fee to platform
        (try! (stx-transfer-memo? platform-contracts-fee recipient platform-treasury
            (unwrap! (to-consensus-buff? "new pot") NOT_FOUND)
        ))

        (try! (nft-mint? stackpot-pot token-id recipient))
        (map-insert token-owner-ids recipient token-id)
        (var-set last-token-id token-id)
        (ok token-id)
    )
)
