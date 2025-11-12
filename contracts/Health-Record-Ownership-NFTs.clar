(define-non-fungible-token health-record uint)
(define-data-var last-token-id uint u0)
(define-data-var last-audit-id uint u0)

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

(define-map audit-log
    uint
    {
        token-id: uint,
        action: (string-ascii 20),
        actor: principal,
        target: (optional principal),
        timestamp: uint,
        result: bool,
    }
)

(define-map emergency-contacts
    {
        patient: principal,
        emergency-contact: principal,
    }
    {
        relationship: (string-ascii 50),
        authorized-at: uint,
        is-active: bool,
    }
)

(define-map emergency-access-log
    uint
    {
        patient: principal,
        emergency-contact: principal,
        token-id: uint,
        accessed-at: uint,
        reason: (string-ascii 100),
    }
)

(define-data-var last-emergency-access-id uint u0)
(define-data-var last-inheritance-id uint u0)
(define-data-var last-analytics-id uint u0)

(define-map inheritance-plans
    uint
    {
        token-id: uint,
        beneficiary: principal,
        lock-period: uint,
        last-activity: uint,
        is-active: bool,
    }
)

(define-map patient-activity
    principal
    uint
)

;; Health Analytics Feature Maps
(define-map health-analytics-records
    uint
    {
        patient: principal,
        metric-type: (string-ascii 50),
        metric-value: uint,
        unit: (string-ascii 20),
        recorded-at: uint,
        is-verified: bool,
        provider: (optional principal),
        metadata: (string-ascii 200),
    }
)

(define-map patient-analytics-summary
    principal
    {
        total-records: uint,
        last-updated: uint,
        avg-metric-count-per-month: uint,
        verified-records: uint,
    }
)

(define-map analytics-permissions
    {
        patient: principal,
        analyzer: principal,
    }
    {
        granted-at: uint,
        expires-at: (optional uint),
        permission-level: (string-ascii 20),
        is-active: bool,
    }
)

(define-data-var contract-owner principal tx-sender)

(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-unauthorized-access (err u103))
(define-constant err-invalid-provider (err u104))
(define-constant err-access-expired (err u105))
(define-constant err-record-inactive (err u106))
(define-constant err-not-emergency-contact (err u107))
(define-constant err-inheritance-locked (err u108))
(define-constant err-not-beneficiary (err u109))
(define-constant err-inheritance-not-found (err u110))
(define-constant err-analytics-not-found (err u111))
(define-constant err-invalid-analytics-permission (err u112))
(define-constant err-analytics-permission-expired (err u113))
(define-constant err-invalid-metric-value (err u114))

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

(define-read-only (get-audit-log (audit-id uint))
    (map-get? audit-log audit-id)
)

(define-read-only (get-last-audit-id)
    (ok (var-get last-audit-id))
)

(define-read-only (get-emergency-contact
        (patient principal)
        (emergency-contact principal)
    )
    (map-get? emergency-contacts {
        patient: patient,
        emergency-contact: emergency-contact,
    })
)

(define-read-only (is-emergency-contact
        (patient principal)
        (emergency-contact principal)
    )
    (let ((contact-data (map-get? emergency-contacts {
            patient: patient,
            emergency-contact: emergency-contact,
        })))
        (match contact-data
            data (get is-active data)
            false
        )
    )
)

(define-read-only (get-emergency-access-log (access-id uint))
    (map-get? emergency-access-log access-id)
)

(define-read-only (get-last-emergency-access-id)
    (ok (var-get last-emergency-access-id))
)

(define-read-only (get-inheritance-plan (inheritance-id uint))
    (map-get? inheritance-plans inheritance-id)
)

(define-read-only (get-last-inheritance-id)
    (ok (var-get last-inheritance-id))
)

(define-read-only (get-patient-activity (patient principal))
    (default-to u0 (map-get? patient-activity patient))
)

(define-read-only (is-inheritance-claimable (inheritance-id uint))
    (match (map-get? inheritance-plans inheritance-id)
        plan (and
            (get is-active plan)
            (> burn-block-height
                (+ (get last-activity plan) (get lock-period plan))
            )
        )
        false
    )
)

;; Health Analytics Read-Only Functions
(define-read-only (get-analytics-record (analytics-id uint))
    (map-get? health-analytics-records analytics-id)
)

(define-read-only (get-last-analytics-id)
    (ok (var-get last-analytics-id))
)

(define-read-only (get-patient-analytics-summary (patient principal))
    (map-get? patient-analytics-summary patient)
)

(define-read-only (get-analytics-permission
        (patient principal)
        (analyzer principal)
    )
    (map-get? analytics-permissions {
        patient: patient,
        analyzer: analyzer,
    })
)

(define-read-only (has-valid-analytics-access
        (patient principal)
        (analyzer principal)
    )
    (let ((permission (map-get? analytics-permissions {
            patient: patient,
            analyzer: analyzer,
        })))
        (match permission
            perm (and
                (get is-active perm)
                (match (get expires-at perm)
                    expiry (< burn-block-height expiry)
                    true
                )
            )
            false
        )
    )
)

(define-read-only (calculate-patient-health-score (patient principal))
    (let ((summary (map-get? patient-analytics-summary patient)))
        (match summary
            data (let (
                    (total (get total-records data))
                    (verified (get verified-records data))
                    (consistency-score (if (> total u0)
                        (* (/ verified total) u100)
                        u0
                    ))
                    (raw-frequency (* (get avg-metric-count-per-month data) u10))
                    (frequency-score (if (< raw-frequency u100)
                        raw-frequency
                        u100
                    ))
                    (weighted-score (+ (* consistency-score u6) (* frequency-score u4)))
                )
                (ok (/ weighted-score u10))
            )
            (ok u0)
        )
    )
)

;; Health Analytics Public Functions
(define-public (record-health-metric
        (metric-type (string-ascii 50))
        (metric-value uint)
        (unit (string-ascii 20))
        (metadata (string-ascii 200))
    )
    (let (
            (analytics-id (+ (var-get last-analytics-id) u1))
            (current-summary (default-to {
                total-records: u0,
                last-updated: u0,
                avg-metric-count-per-month: u0,
                verified-records: u0,
            }
                (map-get? patient-analytics-summary tx-sender)
            ))
        )
        (asserts! (> metric-value u0) err-invalid-metric-value)
        (map-set health-analytics-records analytics-id {
            patient: tx-sender,
            metric-type: metric-type,
            metric-value: metric-value,
            unit: unit,
            recorded-at: burn-block-height,
            is-verified: false,
            provider: none,
            metadata: metadata,
        })
        (map-set patient-analytics-summary tx-sender {
            total-records: (+ (get total-records current-summary) u1),
            last-updated: burn-block-height,
            avg-metric-count-per-month: (get avg-metric-count-per-month current-summary),
            verified-records: (get verified-records current-summary),
        })
        (var-set last-analytics-id analytics-id)
        (ok analytics-id)
    )
)

(define-public (verify-health-metric
        (analytics-id uint)
        (patient principal)
    )
    (let (
            (analytics-record (unwrap! (map-get? health-analytics-records analytics-id)
                err-analytics-not-found
            ))
            (current-summary (unwrap! (map-get? patient-analytics-summary patient)
                err-analytics-not-found
            ))
        )
        (asserts! (is-eq (get patient analytics-record) patient)
            err-unauthorized-access
        )
        (asserts! (is-authorized-provider tx-sender) err-invalid-provider)
        (asserts! (not (get is-verified analytics-record))
            err-unauthorized-access
        )
        (map-set health-analytics-records analytics-id
            (merge analytics-record {
                is-verified: true,
                provider: (some tx-sender),
            })
        )
        (map-set patient-analytics-summary patient
            (merge current-summary { verified-records: (+ (get verified-records current-summary) u1) })
        )
        (ok true)
    )
)

(define-public (grant-analytics-permission
        (analyzer principal)
        (permission-level (string-ascii 20))
        (duration (optional uint))
    )
    (let ((expires-at (match duration
            dur (some (+ burn-block-height dur))
            none
        )))
        (map-set analytics-permissions {
            patient: tx-sender,
            analyzer: analyzer,
        } {
            granted-at: burn-block-height,
            expires-at: expires-at,
            permission-level: permission-level,
            is-active: true,
        })
        (ok true)
    )
)

(define-public (revoke-analytics-permission (analyzer principal))
    (begin
        (map-delete analytics-permissions {
            patient: tx-sender,
            analyzer: analyzer,
        })
        (ok true)
    )
)

(define-public (access-patient-analytics-data
        (patient principal)
        (analytics-id uint)
    )
    (let (
            (analytics-record (unwrap! (map-get? health-analytics-records analytics-id)
                err-analytics-not-found
            ))
            (has-permission (or
                (is-eq tx-sender patient)
                (has-valid-analytics-access patient tx-sender)
            ))
        )
        (asserts! (is-eq (get patient analytics-record) patient)
            err-unauthorized-access
        )
        (asserts! has-permission err-invalid-analytics-permission)
        (ok {
            metric-type: (get metric-type analytics-record),
            metric-value: (get metric-value analytics-record),
            unit: (get unit analytics-record),
            recorded-at: (get recorded-at analytics-record),
            is-verified: (get is-verified analytics-record),
            metadata: (get metadata analytics-record),
        })
    )
)

(define-public (update-analytics-summary-stats (patient principal))
    (let (
            (current-summary (unwrap! (map-get? patient-analytics-summary patient)
                err-analytics-not-found
            ))
            (blocks-per-month u4320) ;; approximately 30 days * 144 blocks per day
            (time-diff (- burn-block-height (get last-updated current-summary)))
            (raw-months (/ time-diff blocks-per-month))
            (months-active (if (> raw-months u1)
                raw-months
                u1
            ))
            (new-avg (/ (get total-records current-summary) months-active))
        )
        (asserts! (is-eq tx-sender patient) err-unauthorized-access)
        (map-set patient-analytics-summary patient
            (merge current-summary {
                avg-metric-count-per-month: new-avg,
                last-updated: burn-block-height,
            })
        )
        (ok true)
    )
)

(define-private (log-audit-event
        (token-id uint)
        (action (string-ascii 20))
        (target (optional principal))
        (result bool)
    )
    (let ((audit-id (+ (var-get last-audit-id) u1)))
        (map-set audit-log audit-id {
            token-id: token-id,
            action: action,
            actor: tx-sender,
            target: target,
            timestamp: burn-block-height,
            result: result,
        })
        (var-set last-audit-id audit-id)
        audit-id
    )
)

(define-public (mint-health-record (record-hash (buff 32)))
    (let ((token-id (+ (var-get last-token-id) u1)))
        (match (nft-mint? health-record token-id tx-sender)
            success (begin
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
                (log-audit-event token-id "mint" none true)
                (ok token-id)
            )
            error (begin
                (log-audit-event token-id "mint" none false)
                (err error)
            )
        )
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
        (log-audit-event token-id "grant-access" (some accessor) true)
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
        (log-audit-event token-id "revoke-access" (some accessor) true)
        (ok true)
    )
)

(define-public (access-record (token-id uint))
    (let (
            (record-data (unwrap! (map-get? record-metadata token-id) err-token-not-found))
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
            (has-access (or (is-eq tx-sender token-owner) (has-valid-access token-id tx-sender)))
        )
        (asserts! (get is-active record-data) err-record-inactive)
        (if has-access
            (begin
                (log-audit-event token-id "access" none true)
                (ok (get record-hash record-data))
            )
            (begin
                (log-audit-event token-id "access" none false)
                err-unauthorized-access
            )
        )
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (match (nft-transfer? health-record token-id sender recipient)
            success (begin
                (log-audit-event token-id "transfer" (some recipient) true)
                (ok success)
            )
            error (begin
                (log-audit-event token-id "transfer" (some recipient) false)
                (err error)
            )
        )
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

(define-public (designate-emergency-contact
        (emergency-contact principal)
        (relationship (string-ascii 50))
    )
    (begin
        (map-set emergency-contacts {
            patient: tx-sender,
            emergency-contact: emergency-contact,
        } {
            relationship: relationship,
            authorized-at: burn-block-height,
            is-active: true,
        })
        (ok true)
    )
)

(define-public (revoke-emergency-contact (emergency-contact principal))
    (begin
        (map-delete emergency-contacts {
            patient: tx-sender,
            emergency-contact: emergency-contact,
        })
        (ok true)
    )
)

(define-public (emergency-access-record
        (token-id uint)
        (patient principal)
        (reason (string-ascii 100))
    )
    (let (
            (record-data (unwrap! (map-get? record-metadata token-id) err-token-not-found))
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
            (is-emergency-authorized (is-emergency-contact patient tx-sender))
            (emergency-access-id (+ (var-get last-emergency-access-id) u1))
        )
        (asserts! (is-eq token-owner patient) err-not-token-owner)
        (asserts! (get is-active record-data) err-record-inactive)
        (asserts! is-emergency-authorized err-not-emergency-contact)
        (map-set emergency-access-log emergency-access-id {
            patient: patient,
            emergency-contact: tx-sender,
            token-id: token-id,
            accessed-at: burn-block-height,
            reason: reason,
        })
        (var-set last-emergency-access-id emergency-access-id)
        (log-audit-event token-id "emergency-access" (some patient) true)
        (ok (get record-hash record-data))
    )
)

(define-private (update-patient-activity (patient principal))
    (map-set patient-activity patient burn-block-height)
)

(define-public (create-inheritance-plan
        (token-id uint)
        (beneficiary principal)
        (lock-period uint)
    )
    (let (
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
            (inheritance-id (+ (var-get last-inheritance-id) u1))
        )
        (asserts! (is-eq token-owner tx-sender) err-not-token-owner)
        (map-set inheritance-plans inheritance-id {
            token-id: token-id,
            beneficiary: beneficiary,
            lock-period: lock-period,
            last-activity: burn-block-height,
            is-active: true,
        })
        (var-set last-inheritance-id inheritance-id)
        (update-patient-activity tx-sender)
        (log-audit-event token-id "inheritance-plan" (some beneficiary) true)
        (ok inheritance-id)
    )
)

(define-public (claim-inheritance (inheritance-id uint))
    (let (
            (plan (unwrap! (map-get? inheritance-plans inheritance-id)
                err-inheritance-not-found
            ))
            (token-id (get token-id plan))
            (token-owner (unwrap! (nft-get-owner? health-record token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender (get beneficiary plan)) err-not-beneficiary)
        (asserts! (get is-active plan) err-inheritance-not-found)
        (asserts! (is-inheritance-claimable inheritance-id)
            err-inheritance-locked
        )
        (match (nft-transfer? health-record token-id token-owner tx-sender)
            success (begin
                (map-set inheritance-plans inheritance-id
                    (merge plan { is-active: false })
                )
                (log-audit-event token-id "inheritance-claim" (some token-owner)
                    true
                )
                (ok token-id)
            )
            error (begin
                (log-audit-event token-id "inheritance-claim" (some token-owner)
                    false
                )
                (err error)
            )
        )
    )
)

(define-public (update-inheritance-activity (inheritance-id uint))
    (let (
            (plan (unwrap! (map-get? inheritance-plans inheritance-id)
                err-inheritance-not-found
            ))
            (token-owner (unwrap! (nft-get-owner? health-record (get token-id plan))
                err-token-not-found
            ))
        )
        (asserts! (is-eq token-owner tx-sender) err-not-token-owner)
        (asserts! (get is-active plan) err-inheritance-not-found)
        (map-set inheritance-plans inheritance-id
            (merge plan { last-activity: burn-block-height })
        )
        (update-patient-activity tx-sender)
        (ok true)
    )
)

(define-public (cancel-inheritance-plan (inheritance-id uint))
    (let (
            (plan (unwrap! (map-get? inheritance-plans inheritance-id)
                err-inheritance-not-found
            ))
            (token-owner (unwrap! (nft-get-owner? health-record (get token-id plan))
                err-token-not-found
            ))
        )
        (asserts! (is-eq token-owner tx-sender) err-not-token-owner)
        (map-set inheritance-plans inheritance-id
            (merge plan { is-active: false })
        )
        (log-audit-event (get token-id plan) "inheritance-cancel" none true)
        (ok true)
    )
)

(define-constant DX-NAME "Health-Record-Ownership-NFTs")
(define-constant DX-VERSION "devtools-001")

(define-read-only (dx-get-metadata)
    (ok {
        name: DX-NAME,
        version: DX-VERSION,
    })
)

(define-read-only (dx-get-contract-principal)
    (ok (as-contract tx-sender))
)

(define-read-only (dx-get-block-height)
    (ok burn-block-height)
)

(define-read-only (dx-ping)
    (ok true)
)

(define-read-only (dx-echo (input (string-ascii 200)))
    (ok input)
)
