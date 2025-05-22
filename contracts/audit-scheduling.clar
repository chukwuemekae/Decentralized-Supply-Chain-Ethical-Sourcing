;; audit-scheduling.clar
;; This contract manages compliance verification through audits

(define-data-var admin principal tx-sender)

;; Map to store auditors
(define-map authorized-auditors principal bool)

;; Map to store scheduled audits
(define-map scheduled-audits uint
  {
    supplier: principal,
    auditor: principal,
    scheduled-date: uint,
    completed: bool,
    result: (optional bool),
    notes: (optional (string-utf8 500))
  }
)

;; Counter for audits
(define-data-var audit-count uint u0)

;; Function to authorize an auditor
(define-public (authorize-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set authorized-auditors auditor true))
  )
)

;; Function to revoke auditor authorization
(define-public (revoke-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set authorized-auditors auditor false))
  )
)

;; Function to schedule an audit
(define-public (schedule-audit (supplier principal) (auditor principal) (scheduled-blocks uint))
  (let ((new-id (+ (var-get audit-count) u1)))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))
      (asserts! (default-to false (map-get? authorized-auditors auditor)) (err u2))
      (map-set scheduled-audits new-id
        {
          supplier: supplier,
          auditor: auditor,
          scheduled-date: (+ block-height scheduled-blocks),
          completed: false,
          result: none,
          notes: none
        }
      )
      (var-set audit-count new-id)
      (ok new-id)
    )
  )
)

;; Function to complete an audit
(define-public (complete-audit (audit-id uint) (passed bool) (notes (optional (string-utf8 500))))
  (let ((audit (map-get? scheduled-audits audit-id)))
    (begin
      (asserts! (is-some audit) (err u1))
      (asserts! (is-eq tx-sender (get auditor (unwrap-panic audit))) (err u2))
      (ok (map-set scheduled-audits audit-id
        (merge (unwrap-panic audit)
          {
            completed: true,
            result: (some passed),
            notes: notes
          }
        )
      ))
    )
  )
)

;; Function to get audit details
(define-read-only (get-audit (audit-id uint))
  (map-get? scheduled-audits audit-id)
)

;; Function to check if an auditor is authorized
(define-read-only (is-authorized-auditor (auditor principal))
  (default-to false (map-get? authorized-auditors auditor))
)
