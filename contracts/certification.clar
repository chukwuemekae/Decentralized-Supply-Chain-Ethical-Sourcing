;; certification.clar
;; This contract records authenticated ethical claims

(define-data-var admin principal tx-sender)

;; Map to store certifications
(define-map certifications uint
  {
    supplier: principal,
    standard-id: uint,
    issuer: principal,
    issue-date: uint,
    expiration-date: uint,
    revoked: bool,
    metadata: (string-utf8 500)
  }
)

;; Map to store authorized certification issuers
(define-map authorized-issuers principal bool)

;; Counter for certifications
(define-data-var certification-count uint u0)

;; Function to authorize an issuer
(define-public (authorize-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set authorized-issuers issuer true))
  )
)

;; Function to revoke issuer authorization
(define-public (revoke-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set authorized-issuers issuer false))
  )
)

;; Function to issue a certification
(define-public (issue-certification
  (supplier principal)
  (standard-id uint)
  (validity-period uint)
  (metadata (string-utf8 500)))
  (let ((new-id (+ (var-get certification-count) u1)))
    (begin
      (asserts! (default-to false (map-get? authorized-issuers tx-sender)) (err u1))
      (map-set certifications new-id
        {
          supplier: supplier,
          standard-id: standard-id,
          issuer: tx-sender,
          issue-date: block-height,
          expiration-date: (+ block-height validity-period),
          revoked: false,
          metadata: metadata
        }
      )
      (var-set certification-count new-id)
      (ok new-id)
    )
  )
)

;; Function to revoke a certification
(define-public (revoke-certification (certification-id uint))
  (let ((cert (map-get? certifications certification-id)))
    (begin
      (asserts! (is-some cert) (err u1))
      (asserts! (or
        (is-eq tx-sender (var-get admin))
        (is-eq tx-sender (get issuer (unwrap-panic cert)))
      ) (err u2))
      (ok (map-set certifications certification-id
        (merge (unwrap-panic cert) { revoked: true })
      ))
    )
  )
)

;; Function to check if a certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (let ((cert (map-get? certifications certification-id)))
    (if (is-some cert)
      (let ((cert-data (unwrap-panic cert)))
        (and
          (not (get revoked cert-data))
          (<= block-height (get expiration-date cert-data))
        )
      )
      false
    )
  )
)

;; Function to get certification details
(define-read-only (get-certification (certification-id uint))
  (map-get? certifications certification-id)
)
