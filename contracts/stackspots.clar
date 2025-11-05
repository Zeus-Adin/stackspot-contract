(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait stackspot-trait .stackspot-trait.stackspot-trait)

;; Platform address
(define-constant platform-treasury tx-sender)

;; Core errors
(define-constant ERR_ADMIN_ONLY (err u1102))
(define-constant ERR_UNAUTHORIZED (err u1101))
(define-constant ERR_NOT_FOUND (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1301))
(define-constant ERR_INVALID_ARGUMENT_VALUE (err u1202))
(define-constant ERR_NOT_CONTRACT_AUDITED (err u1103))

;; NFT errors
(define-constant ERR_OWNER_ONLY (err u200))
(define-constant ERR_NOT_TOKEN_OWNER (err u201))
(define-constant ERR_OWNER_NOT_PERMITTED (err u202))
(define-constant ERR_NOT_PERMITTED (err u203))


;; NFT Declaration
(define-non-fungible-token stackpot-pot uint)
(define-map pot-contract-with-index principal uint)
(define-map pot-id-info uint {pot-id: uint, pot-name: (string-ascii 255), pot-owner: principal, pot-contract: principal})

;; NFT variables
(define-data-var last-pot-index uint u0)


;; Core actions
(define-data-var fee uint u0)
(define-public (update-fee (newfee uint))
    (begin
        (asserts! (is-eq tx-sender platform-treasury) ERR_ADMIN_ONLY)
        (ok (var-set fee newfee))
    )
)
(define-read-only (get-fee)
    (var-get fee)
)

(define-public (register-pot (pot-values {
    owner: principal,
    contract: principal,
    contract-sha-hash: (string-ascii 64),
}))
    (let (
            (owner (get owner pot-values))
            (contract-address (get contract pot-values))
            (contract-hash (get contract-sha-hash pot-values))

            (contract-info (unwrap! (principal-destruct? contract-address) ERR_NOT_FOUND))
            (contract-name (get name contract-info))
            (contract-version (get version contract-info))
            (contract-hash-bytes (get hash-bytes contract-info))
            (new-pot-owner-balance (stx-get-balance owner))

            (platform-contracts-fee (var-get fee))
        )
        (asserts! (contract-call? .stackspot-admin can-deploy-pot) ERR_UNAUTHORIZED)
        (asserts! (> new-pot-owner-balance platform-contracts-fee) ERR_INSUFFICIENT_BALANCE)
        (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
        (asserts! (> (len contract-hash) u0) ERR_INVALID_ARGUMENT_VALUE)
        ;; Mint NFT
        (try! (mint contract-address))

        ;; Log pot registered
        (try! (log-pot {
            pot-id: (var-get last-pot-index),
            pot-address: contract-address,
            contract-sha-hash: contract-hash,
            pot-owner: owner,
            pot-name: contract-name,
            pot-version: contract-version,
            pot-hash-bytes: contract-hash-bytes,
            pot-registry-timestamp: stacks-block-height,
            pot-platform-contract-fee: platform-contracts-fee
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
    pot-admin: principal,
    pot-round: uint,
    pot-participants: uint,
    pot-value: uint,
    ;; Pot Config Values
    pot-cycle: uint,
    pot-reward-token: (string-ascii 16),    
    pot-min-amount: uint,
    pot-max-participants: uint,    
    ;; Pot Starter Values
    pot-starter-address: principal,
    pot-starter-amount: uint,
    ;; Claimer Values
    claimer-address: principal,
    claimer-amount: uint,    
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
            (pot-address (unwrap! (nft-get-owner? stackpot-pot pot-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq pot-address contract-caller) ERR_NOT_PERMITTED)
        (ok (contract-call? .stackspot-winners log-winner winner-values))
    )
)

(define-public (log-pot (pot-values {
    pot-id: uint,
    pot-address: principal,
    contract-sha-hash: (string-ascii 64),
    pot-owner: principal,
    pot-name: (optional (string-ascii 255)),
    pot-version: (buff 1),
    pot-hash-bytes: (buff 20),
    pot-platform-contract-fee: uint,
    pot-registry-timestamp: uint
}))
    (let (
            (pot-id (get pot-id pot-values))
            (pot-address (unwrap! (nft-get-owner? stackpot-pot pot-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq pot-address contract-caller) ERR_NOT_PERMITTED)
        (is-ok (contract-call? .stackspot-registry log-pot pot-values))
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
        (asserts! false ERR_NOT_PERMITTED)
        (nft-transfer? stackpot-pot token-id sender recipient)
    )
)

(define-public (mint (recipient principal))
    (let 
        (
            (token-id (+ (var-get last-pot-index) u1))
            (platform-contracts-fee (var-get fee))
            (contract-info (unwrap! (principal-destruct? recipient) ERR_NOT_FOUND))
            (contract-name (get name contract-info))
        )
        ;; Validate's if the recipient is a contract principal and not a just principal
        (asserts! (is-some contract-name) ERR_UNAUTHORIZED)
        ;; Validate's if the tx-sender is not the platform treasury
        (asserts! (not (is-eq tx-sender platform-treasury)) ERR_UNAUTHORIZED)
        ;; Validate's if the platform treasury is not the recipient
        (asserts! (not (is-eq platform-treasury recipient)) ERR_UNAUTHORIZED)

        ;; ;; Transfer fee to platform
        (try! (stx-transfer-memo? platform-contracts-fee tx-sender platform-treasury (unwrap! (to-consensus-buff? "pot mint") ERR_NOT_FOUND)))

        (try! (nft-mint? stackpot-pot token-id recipient))
        (map-insert pot-contract-with-index recipient token-id)
        (map-insert pot-id-info token-id {pot-id: token-id, pot-name: (unwrap! contract-name ERR_NOT_FOUND), pot-owner: recipient, pot-contract: recipient})
        (var-set last-pot-index token-id)

        ;; Print event
        (print {
            event: "pot mint",
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
    (let 
        (
            (pot-index (unwrap! (unwrap! (get-token-id owner) ERR_NOT_FOUND) ERR_NOT_FOUND))
            (pot-info (unwrap! (map-get? pot-id-info pot-index) ERR_NOT_FOUND))
        )
        (ok pot-info)
    )
)

(define-public (dispatch-principals (contract <stackspot-trait>))
    (let 
        (
            (pot-detailes (unwrap! (get-pot-info (contract-of contract)) ERR_NOT_FOUND))
            (pot-contract (get pot-contract pot-detailes))
        )
        (asserts! (is-eq pot-contract (contract-of contract)) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller (contract-of contract)) ERR_UNAUTHORIZED)

        (try! (contract-call? .stackspot-distribute dispatch-principals contract))
        (ok true)
    )
)

(define-public (dispatch-rewards (winner-values {participant: principal, amount: uint}) (contract <stackspot-trait>))
    (let 
        (
            (pot-detailes (unwrap! (get-pot-info (contract-of contract)) ERR_NOT_FOUND))  
            (pot-contract (get pot-contract pot-detailes))
            (is-audited (unwrap! (contract-call? .stackspot-audited-contracts is-audited-contract contract) ERR_NOT_FOUND))
        )
        (asserts! is-audited ERR_NOT_CONTRACT_AUDITED)
        (asserts! (is-eq pot-contract (contract-of contract)) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller (contract-of contract)) ERR_UNAUTHORIZED)

        (try! (contract-call? .stackspot-distribute dispatch-rewards winner-values contract))
        (ok true)
    )
)

(define-public (delegate-treasury (contract <stackspot-trait>) (delegate-to principal))
    (let 
        (
            (pot-detailes (unwrap! (get-pot-info (contract-of contract)) ERR_NOT_FOUND))  
            (pot-contract (get pot-contract pot-detailes))
            (is-audited (unwrap! (contract-call? .stackspot-audited-contracts is-audited-contract contract) ERR_NOT_FOUND))
        )
        (asserts! is-audited ERR_NOT_CONTRACT_AUDITED)
        (asserts! (is-eq pot-contract (contract-of contract)) ERR_UNAUTHORIZED)
        (asserts! (is-eq contract-caller (contract-of contract)) ERR_UNAUTHORIZED)

        (try! (contract-call? .stackspot-distribute delegate-treasury contract delegate-to))
        (ok true)
    )
)

(update-fee u100000)