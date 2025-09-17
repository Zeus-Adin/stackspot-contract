(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait stackpot-pot-trait .stackpot-pot-trait.stackpot-pot-trait)

;; Core errors
(define-constant UNAUTHORIZED_POT_OWNER (err u108))
(define-constant NOT_FOUND (err u109))
(define-constant INSUFFICIENT_BALANCE (err u110))
(define-constant UNAUTHORIZED_POT (err u111))

;; Platform address
(define-constant platform-treasury tx-sender)

;; NFT Declaration
(define-non-fungible-token stackpot-pot uint)
(define-map pot-contract-with-index
  principal
  uint
)
(define-map pot-id-info
  uint
  {
    pot-id: uint,
    pot-name: (string-ascii 255),
    pot-owner: principal,
    pot-contract: principal,
  }
)

;; NFT variables
(define-data-var last-pot-index uint u0)

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
    (asserts! (>= new-pot-owner-balance platform-contracts-fee)
      INSUFFICIENT_BALANCE
    )
    (asserts! (is-eq tx-sender owner) UNAUTHORIZED_POT_OWNER)

    ;; Mint NFT
    (try! (mint contract-address))

    ;; Log pot registered
    (try! (log-participant {
      pot-id: (var-get last-pot-index),
      participant-id: u0,
      participant-address: contract-address,
      participant-amount: new-pot-owner-balance,
      participant-timestamp: stacks-block-height,
    }))

    ;; Print event
    (print {
      event: "pot registered",
      nft-id: (var-get last-pot-index),
      owner: owner,
      contract-address: contract-address,
      contract-name: contract-name,
      contract-version: contract-version,
      contract-hash-bytes: contract-hash-bytes,
      platform-contract-fee: platform-contracts-fee,
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
  },
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
  (ok (var-get last-pot-index))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stackpot-pot token-id))
)

(define-read-only (get-token-id (owner principal))
  (ok (map-get? pot-contract-with-index owner))
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
      (token-id (+ (var-get last-pot-index) u1))
      (platform-contracts-fee (var-get fee))
      (contract-info (unwrap! (principal-destruct? recipient) NOT_FOUND))
      (contract-name (get name contract-info))
    )
    ;; Validate's if the recipient is a contract principal and not a just principal
    (asserts! (is-some contract-name) UNAUTHORIZED_POT)
    ;; Validate's if the tx-sender is not the platform treasury
    (asserts! (not (is-eq tx-sender platform-treasury)) err-owner-not-permitted)
    ;; Validate's if the platform treasury is not the recipient
    (asserts! (not (is-eq platform-treasury recipient)) err-owner-not-permitted)

    ;;;;  Transfer fee to platform
    (try! (stx-transfer-memo? platform-contracts-fee tx-sender platform-treasury
      (unwrap! (to-consensus-buff? "new pot") NOT_FOUND)
    ))

    (try! (nft-mint? stackpot-pot token-id recipient))
    (map-insert pot-contract-with-index recipient token-id)
    (map-insert pot-id-info token-id {
      pot-id: token-id,
      pot-name: (unwrap! contract-name NOT_FOUND),
      pot-owner: recipient,
      pot-contract: recipient,
    })
    (var-set last-pot-index token-id)

    ;; Print event
    (print {
      event: "pot minted",
      contract-name: contract-name,
      token-id: token-id,
      recipient: recipient,
      tx-sender: tx-sender,
      platform-contracts-fee: platform-contracts-fee,
    })

    (ok token-id)
  )
)

(define-read-only (get-pot-info (owner principal))
  (let (
      (pot-index (unwrap! (unwrap! (get-token-id owner) NOT_FOUND) NOT_FOUND))
      (pot-info (unwrap! (map-get? pot-id-info pot-index) NOT_FOUND))
    )
    (ok pot-info)
  )
)

(update-fee u100000)
(define-public (claiming-pot-reward-return-principals
    (pot-id uint)
    (contract <stackpot-pot-trait>)
  )
  (let ((pot-detailes (unwrap! (get-pot-info (contract-of contract)) NOT_FOUND)))
    (try! (contract-call?
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stackspot-distribute-rewards
      dispatch-principals-and-rewards pot-id contract pot-detailes
    ))
    (ok true)
  )
)
