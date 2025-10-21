;; Medical Device Lifecycle Tracker Smart Contract
;; A transparent blockchain-based system for tracking medical devices throughout their entire lifecycle
;; from manufacturing through deployment, including regulatory certifications and maintenance records

;; Trait definition for medical device lifecycle management
(define-trait device-lifecycle-management
  (
    (register-device (uint uint) (response bool uint))
    (update-device-status (uint uint) (response bool uint))
    (get-device-history (uint) (response (list 10 {status: uint, timestamp: uint}) uint))
    (add-certification (uint uint principal) (response bool uint))
    (verify-certification (uint uint) (response bool uint))
  )
)

;; Lifecycle stage constants
(define-constant lifecycle-manufactured u1)
(define-constant lifecycle-testing u2)
(define-constant lifecycle-deployed u3)
(define-constant lifecycle-maintained u4)
(define-constant lifecycle-recalled u5)

;; Regulatory certification type constants
(define-constant cert-fda-approval u1)
(define-constant cert-ce-marking u2)
(define-constant cert-iso-standard u3)
(define-constant cert-safety-compliance u4)

;; Recall severity levels
(define-constant recall-severity-critical u1)
(define-constant recall-severity-major u2)
(define-constant recall-severity-minor u3)

;; Error code constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-DEVICE-NOT-FOUND (err u2))
(define-constant ERR-STATUS-UPDATE-FAILED (err u3))
(define-constant ERR-INVALID-LIFECYCLE-STAGE (err u4))
(define-constant ERR-INVALID-CERT-TYPE (err u5))
(define-constant ERR-CERTIFICATION-ALREADY-EXISTS (err u6))
(define-constant ERR-DEVICE-ALREADY-RECALLED (err u7))
(define-constant ERR-INVALID-RECALL-SEVERITY (err u8))
(define-constant ERR-RECALL-NOT-FOUND (err u9))
(define-constant ERR-INVALID-BATCH-ID (err u10))
(define-constant ERR-INVALID-BATCH-COUNT (err u11))
(define-constant ERR-INVALID-REASON-LENGTH (err u12))

;; Validation constants
(define-constant min-device-id u1)
(define-constant max-device-id u1000000)
(define-constant max-history-entries u10)
(define-constant max-recall-reason-length u256)
(define-constant min-recall-reason-length u10)
(define-constant max-batch-id u1000000)
(define-constant max-affected-batches u10000)
(define-constant max-devices-per-batch u100000)

;; Administrative state variables
(define-data-var admin-principal principal tx-sender)
(define-data-var global-timestamp-counter uint u0)
(define-data-var total-recalls-issued uint u0)

;; Core data storage: maps device identifiers to their complete details
(define-map registered-devices 
  {device-identifier: uint} 
  {
    device-owner: principal,
    active-lifecycle-stage: uint,
    lifecycle-history: (list 10 {status: uint, timestamp: uint}),
    is-recalled: bool
  }
)

;; Certification storage: tracks all certifications issued for devices
(define-map issued-certifications
  {device-identifier: uint, certification-type: uint}
  {
    certifying-authority: principal,
    issuance-timestamp: uint,
    is-currently-valid: bool
  }
)

;; Authority registry: maintains list of approved regulatory bodies
(define-map approved-authorities
  {authority-principal: principal, certification-type: uint}
  {is-approved: bool}
)

;; Recall tracking: comprehensive recall management system
(define-map device-recalls
  {device-identifier: uint}
  {
    recall-issuer: principal,
    recall-timestamp: uint,
    severity-level: uint,
    reason-description: (string-ascii 256),
    is-active: bool,
    affected-batch-count: uint
  }
)

;; Batch recall tracking: for recalling multiple devices at once
(define-map batch-recalls
  {batch-id: uint}
  {
    issuer: principal,
    recall-timestamp: uint,
    severity-level: uint,
    total-devices-affected: uint,
    reason-description: (string-ascii 256)
  }
)

;; Generates and increments a unique timestamp for tracking events
(define-private (generate-next-timestamp)
  (begin
    (var-set global-timestamp-counter (+ (var-get global-timestamp-counter) u1))
    (var-get global-timestamp-counter)
  )
)

;; Checks if the caller is the contract administrator
(define-read-only (check-admin-privileges (caller principal))
  (is-eq caller (var-get admin-principal))
)

;; Validates that a lifecycle stage value is within accepted constants
(define-private (validate-lifecycle-stage (stage-value uint))
  (or 
    (is-eq stage-value lifecycle-manufactured)
    (is-eq stage-value lifecycle-testing)
    (is-eq stage-value lifecycle-deployed)
    (is-eq stage-value lifecycle-maintained)
    (is-eq stage-value lifecycle-recalled)
  )
)

;; Validates that a certification type is recognized by the system
(define-private (validate-certification-type (cert-value uint))
  (or
    (is-eq cert-value cert-fda-approval)
    (is-eq cert-value cert-ce-marking)
    (is-eq cert-value cert-iso-standard)
    (is-eq cert-value cert-safety-compliance)
  )
)

;; Validates recall severity level
(define-private (validate-recall-severity (severity uint))
  (or
    (is-eq severity recall-severity-critical)
    (is-eq severity recall-severity-major)
    (is-eq severity recall-severity-minor)
  )
)

;; Ensures device identifier is within acceptable range
(define-private (validate-device-identifier (device-id uint))
  (and (>= device-id min-device-id) (<= device-id max-device-id))
)

;; Validates batch identifier is within acceptable range
(define-private (validate-batch-identifier (batch-id uint))
  (and (>= batch-id u1) (<= batch-id max-batch-id))
)

;; Validates affected batch count is within acceptable range
(define-private (validate-affected-batches (batch-count uint))
  (and (>= batch-count u0) (<= batch-count max-affected-batches))
)

;; Validates devices affected count is within acceptable range
(define-private (validate-devices-affected (device-count uint))
  (and (> device-count u0) (<= device-count max-devices-per-batch))
)

;; Validates recall reason string length
(define-private (validate-recall-reason (reason (string-ascii 256)))
  (let
    ((reason-length (len reason)))
    (and 
      (>= reason-length min-recall-reason-length)
      (<= reason-length max-recall-reason-length)
    )
  )
)

;; Determines if a principal is an approved regulatory authority for a certification type
(define-private (check-regulatory-authority (authority-address principal) (cert-value uint))
  (default-to 
    false
    (get is-approved (map-get? approved-authorities {authority-principal: authority-address, certification-type: cert-value}))
  )
)

;; Ensures authority principal meets security requirements
(define-private (validate-authority-principal (authority-address principal))
  (and 
    (not (is-eq authority-address (var-get admin-principal)))
    (not (is-eq authority-address tx-sender))
    (not (is-eq authority-address 'SP000000000000000000002Q6VF78))
  )
)

;; Registers a new medical device in the tracking system
(define-public (register-device (device-id uint) (initial-stage uint))
  (begin
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! (validate-lifecycle-stage initial-stage) ERR-INVALID-LIFECYCLE-STAGE)
    (asserts! (or (check-admin-privileges tx-sender) (is-eq initial-stage lifecycle-manufactured)) ERR-UNAUTHORIZED-ACCESS)
    
    (map-set registered-devices 
      {device-identifier: device-id}
      {
        device-owner: tx-sender,
        active-lifecycle-stage: initial-stage,
        lifecycle-history: (list {status: initial-stage, timestamp: (generate-next-timestamp)}),
        is-recalled: false
      }
    )
    (ok true)
  )
)

;; Updates the lifecycle stage of an existing device
(define-public (update-device-status (device-id uint) (next-stage uint))
  (let 
    (
      (device-record (unwrap! (map-get? registered-devices {device-identifier: device-id}) ERR-DEVICE-NOT-FOUND))
      (new-timestamp (generate-next-timestamp))
      (new-entry {status: next-stage, timestamp: new-timestamp})
      (updated-history (unwrap-panic (as-max-len? (append (get lifecycle-history device-record) new-entry) u10)))
    )
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! (validate-lifecycle-stage next-stage) ERR-INVALID-LIFECYCLE-STAGE)
    (asserts! 
      (or 
        (check-admin-privileges tx-sender)
        (is-eq (get device-owner device-record) tx-sender)
      ) 
      ERR-UNAUTHORIZED-ACCESS
    )
    
    (map-set registered-devices 
      {device-identifier: device-id}
      (merge device-record 
        {
          active-lifecycle-stage: next-stage,
          lifecycle-history: updated-history
        }
      )
    )
    (ok true)
  )
)

;; Adds an approved regulatory authority to the system
(define-public (add-regulatory-body (authority-address principal) (cert-value uint))
  (begin
    (asserts! (check-admin-privileges tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-certification-type cert-value) ERR-INVALID-CERT-TYPE)
    (asserts! (validate-authority-principal authority-address) ERR-UNAUTHORIZED-ACCESS)
    
    (map-set approved-authorities
      {authority-principal: authority-address, certification-type: cert-value}
      {is-approved: true}
    )
    (ok true)
  )
)

;; Issues a certification for a medical device
(define-public (add-certification (device-id uint) (cert-value uint))
  (begin
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! (validate-certification-type cert-value) ERR-INVALID-CERT-TYPE)
    (asserts! (check-regulatory-authority tx-sender cert-value) ERR-UNAUTHORIZED-ACCESS)
    
    (asserts! 
      (is-none 
        (map-get? issued-certifications {device-identifier: device-id, certification-type: cert-value})
      )
      ERR-CERTIFICATION-ALREADY-EXISTS
    )
    
    (let
      ((validated-device-id device-id)
       (validated-cert-type cert-value))
      (map-set issued-certifications
        {device-identifier: validated-device-id, certification-type: validated-cert-type}
        {
          certifying-authority: tx-sender,
          issuance-timestamp: (generate-next-timestamp),
          is-currently-valid: true
        }
      )
      (ok true)
    )
  )
)

;; Verifies if a device holds a valid certification
(define-read-only (verify-certification (device-id uint) (cert-value uint))
  (let
    (
      (cert-record (unwrap! 
        (map-get? issued-certifications {device-identifier: device-id, certification-type: cert-value})
        ERR-INVALID-CERT-TYPE
      ))
    )
    (ok (get is-currently-valid cert-record))
  )
)

;; Revokes a previously issued certification
(define-public (revoke-certification (device-id uint) (cert-value uint))
  (begin
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! (validate-certification-type cert-value) ERR-INVALID-CERT-TYPE)
    
    (let
      (
        (cert-record (unwrap! 
          (map-get? issued-certifications {device-identifier: device-id, certification-type: cert-value})
          ERR-INVALID-CERT-TYPE
        ))
        (validated-device-id device-id)
        (validated-cert-type cert-value)
      )
      (asserts! 
        (or
          (check-admin-privileges tx-sender)
          (is-eq (get certifying-authority cert-record) tx-sender)
        )
        ERR-UNAUTHORIZED-ACCESS
      )
      
      (map-set issued-certifications
        {device-identifier: validated-device-id, certification-type: validated-cert-type}
        (merge cert-record {is-currently-valid: false})
      )
      (ok true)
    )
  )
)

;; Issues a recall for a specific medical device
(define-public (issue-device-recall 
  (device-id uint) 
  (severity uint) 
  (reason (string-ascii 256))
  (affected-batches uint))
  (let
    (
      (device-record (unwrap! (map-get? registered-devices {device-identifier: device-id}) ERR-DEVICE-NOT-FOUND))
      (recall-timestamp (generate-next-timestamp))
      (new-history-entry {status: lifecycle-recalled, timestamp: recall-timestamp})
      (updated-history (unwrap-panic (as-max-len? (append (get lifecycle-history device-record) new-history-entry) u10)))
      (validated-reason reason)
      (validated-batches affected-batches)
    )
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! (validate-recall-severity severity) ERR-INVALID-RECALL-SEVERITY)
    (asserts! (validate-recall-reason validated-reason) ERR-INVALID-REASON-LENGTH)
    (asserts! (validate-affected-batches validated-batches) ERR-INVALID-BATCH-COUNT)
    (asserts! (check-admin-privileges tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (get is-recalled device-record)) ERR-DEVICE-ALREADY-RECALLED)
    
    (map-set device-recalls
      {device-identifier: device-id}
      {
        recall-issuer: tx-sender,
        recall-timestamp: recall-timestamp,
        severity-level: severity,
        reason-description: validated-reason,
        is-active: true,
        affected-batch-count: validated-batches
      }
    )
    
    (map-set registered-devices
      {device-identifier: device-id}
      (merge device-record 
        {
          is-recalled: true,
          active-lifecycle-stage: lifecycle-recalled,
          lifecycle-history: updated-history
        }
      )
    )
    
    (var-set total-recalls-issued (+ (var-get total-recalls-issued) u1))
    (ok true)
  )
)

;; Resolves an active recall after corrective action
(define-public (resolve-device-recall (device-id uint))
  (let
    (
      (recall-record (unwrap! (map-get? device-recalls {device-identifier: device-id}) ERR-RECALL-NOT-FOUND))
    )
    (asserts! (validate-device-identifier device-id) ERR-DEVICE-NOT-FOUND)
    (asserts! 
      (or
        (check-admin-privileges tx-sender)
        (is-eq (get recall-issuer recall-record) tx-sender)
      )
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (get is-active recall-record) ERR-RECALL-NOT-FOUND)
    
    (map-set device-recalls
      {device-identifier: device-id}
      (merge recall-record {is-active: false})
    )
    (ok true)
  )
)

;; Issues a batch recall affecting multiple devices
(define-public (issue-batch-recall
  (batch-id uint)
  (severity uint)
  (reason (string-ascii 256))
  (devices-affected uint))
  (let
    (
      (validated-batch-id batch-id)
      (validated-reason reason)
      (validated-devices devices-affected)
    )
    (asserts! (check-admin-privileges tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-recall-severity severity) ERR-INVALID-RECALL-SEVERITY)
    (asserts! (validate-batch-identifier validated-batch-id) ERR-INVALID-BATCH-ID)
    (asserts! (validate-recall-reason validated-reason) ERR-INVALID-REASON-LENGTH)
    (asserts! (validate-devices-affected validated-devices) ERR-INVALID-BATCH-COUNT)
    
    (map-set batch-recalls
      {batch-id: validated-batch-id}
      {
        issuer: tx-sender,
        recall-timestamp: (generate-next-timestamp),
        severity-level: severity,
        total-devices-affected: validated-devices,
        reason-description: validated-reason
      }
    )
    
    (var-set total-recalls-issued (+ (var-get total-recalls-issued) validated-devices))
    (ok true)
  )
)

;; Retrieves recall information for a specific device
(define-read-only (get-recall-details (device-id uint))
  (ok (map-get? device-recalls {device-identifier: device-id}))
)

;; Checks if a device is currently under recall
(define-read-only (check-recall-status (device-id uint))
  (let
    (
      (device-record (unwrap! (map-get? registered-devices {device-identifier: device-id}) ERR-DEVICE-NOT-FOUND))
    )
    (ok (get is-recalled device-record))
  )
)

;; Returns total number of recalls issued by the system
(define-read-only (get-total-recalls)
  (ok (var-get total-recalls-issued))
)

;; Retrieves batch recall information
(define-read-only (get-batch-recall-info (batch-id uint))
  (ok (map-get? batch-recalls {batch-id: batch-id}))
)

;; Retrieves the complete lifecycle history of a device
(define-read-only (get-device-history (device-id uint))
  (let 
    (
      (device-record (unwrap! (map-get? registered-devices {device-identifier: device-id}) ERR-DEVICE-NOT-FOUND))
    )
    (ok (get lifecycle-history device-record))
  )
)

;; Returns the current lifecycle stage of a device
(define-read-only (get-device-status (device-id uint))
  (let 
    (
      (device-record (unwrap! (map-get? registered-devices {device-identifier: device-id}) ERR-DEVICE-NOT-FOUND))
    )
    (ok (get active-lifecycle-stage device-record))
  )
)

;; Retrieves detailed information about a specific certification
(define-read-only (get-certification-details (device-id uint) (cert-value uint))
  (ok (map-get? issued-certifications {device-identifier: device-id, certification-type: cert-value}))
)