(use-trait nft-trait .nft-trait.nft-trait)

(define-non-fungible-token health-record uint)

(define-data-var last-token-id uint u0)

(define-map token-count
    
principal
    
uint

)

(define-map record-metadata
    
uint
    
{
    
    patient: principal,
    
    record-hash: (buff 32),
    
    created-at: uint,
    
    is-active: bool,
    
}

)

(define-map access-permissions
    
{
    
    token-id: uint,
    
    accessor: principal,
    
}
    
{
    
    granted-by: principal,
    
    granted-at: uint,
    
    expires-at: (optional uint),
    
    access-type: (string-ascii 20),
    
}

)

(define-map authorized-providers
    
principal
    
bool

)

(define-data-var contract-owner principal tx-sender)

(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-unauthorized-access (err u103))
(define-constant err-invalid-provider (err u104))
(define-constant err-access-expired (err u105))
(define-constant err-record-inactive (err u106))

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? health-record token-id))
)

(define-read-only (get-record-metadata (token-id uint))
    (map-get? record-metadata token-id)
)

(define-read-only (get-access-permission
        (token-id uint)
        (accessor principal)
    )
    (map-get? access-permissions {
        token-id: token-id,
        accessor: accessor,
    })
)

(define-read-only (has-valid-access
        (token-id uint)
        (accessor principal)
    )
    (let (
            (permission (map-get? access-permissions {
                token-id: token-id,
                accessor: accessor,
            }))
            (record-data (map-get? record-metadata token-id))
        )
        (match permission
            perm (match record-data
                record (and
                    (get is-active record)
                    (match (get expires-at perm)
                        expiry (< burn-block-height expiry)
                        true
                    )
                )
                false
            )
            false
        )
    )
)

(define-read-only (is-authorized-provider (provider principal))
    (default-to false (map-get? authorized-providers provider))
)

(define-public (mint-health-record (record-hash (buff 32)))
    (let ((token-id (+ (var-get last-token-id) u1)))
        (try! (nft-mint? health-record token-id tx-sender))
        (map-set record-metadata token-id {
            patient: tx-sender,
            record-hash: record-hash,
            created-at: burn-block-height,
            is-active: true,
        })
        (map-set token-count tx-sender
            (+ (default-to u0 (map-get? token-count tx-sender)) u1)
        )
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (grant-access
        (token-id uint)
        (accessor principal)
        (access-type (string-ascii 20))
        (duration (optional uint))
    )
    (let (
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
            (expires-at (match duration
                dur (some (+ burn-block-height dur))
                none
            ))
        )
        (asserts! (is-eq token-owner tx-sender) err-not-token-owner)
        (map-set access-permissions {
            token-id: token-id,
            accessor: accessor,
        } {
            granted-by: tx-sender,
            granted-at: burn-block-height,
            expires-at: expires-at,
            access-type: access-type,
        })
        (ok true)
    )
)

(define-public (revoke-access
        (token-id uint)
        (accessor principal)
    )
    (let ((token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found)))
        (asserts! (is-eq token-owner tx-sender) err-not-token-owner)
        (map-delete access-permissions {
            token-id: token-id,
            accessor: accessor,
        })
        (ok true)
    )
)

(define-public (access-record (token-id uint))
    (let (
            (record-data (unwrap! (map-get? record-metadata token-id) err-token-not-found))
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
        )
        (asserts! (get is-active record-data) err-record-inactive)
        (asserts!
            (or (is-eq tx-sender token-owner) (has-valid-access token-id tx-sender))
            err-unauthorized-access
        )
        (ok (get record-hash record-data))
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? health-record token-id sender recipient)
    )
)

(define-public (authorize-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-set authorized-providers provider true)
        (ok true)
    )
)

(define-public (revoke-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-delete authorized-providers provider)
        (ok true)
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (var-set contract-owner new-owner)
        (ok true)
    )
)
