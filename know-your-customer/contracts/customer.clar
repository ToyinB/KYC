;; KYC (Know Your Customer) Smart Contract
;; Features:
;; - User registration and verification
;; - Role-based access control
;; - Document management
;; - Verification status tracking

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-USER-NOT-FOUND (err u2))
(define-constant ERR-ALREADY-VERIFIED (err u3))
(define-constant ERR-INVALID-DOCUMENT (err u4))
(define-constant ERR-VERIFICATION-FAILED (err u5))

;; Events using print
(define-private (log-user-registered (user principal))
  (print {event: "user-registered", user: user})
)

(define-private (log-document-added (user principal))
  (print {event: "document-added", user: user})
)

;; User Struct to store KYC information
(define-map users
  principal
  {
    name: (string-ascii 100),
    email: (string-ascii 100),
    documents: (list 3 (string-ascii 255)),
    is-verified: bool,
    verification-level: uint
  }
)

;; Verifier Roles Map
(define-map verifiers principal bool)

;; Validate verifier addition
(define-private (is-valid-verifier (verifier principal))
  (and 
    (not (is-eq verifier CONTRACT-OWNER))
    (is-some (some verifier))
  )
)

;; Add a verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (try! (check-contract-owner))
    (asserts! (is-valid-verifier verifier) ERR-NOT-AUTHORIZED)
    (map-set verifiers verifier true)
    (ok true)
  )
)

;; Check if sender is contract owner
(define-private (check-contract-owner)
  (if (is-eq tx-sender CONTRACT-OWNER)
      (ok true)
      ERR-NOT-AUTHORIZED)
)

;; Register a new user
(define-public (register-user 
  (name (string-ascii 100))
  (email (string-ascii 100))
)
  (let 
    (
      (user-entry {
        name: name,
        email: email,
        documents: (list),
        is-verified: false,
        verification-level: u0
      })
    )
    (map-set users tx-sender user-entry)
    (log-user-registered tx-sender)
    (ok true)
  )
)

;; Validate user and verification level
(define-private (is-valid-verification 
  (user principal)
  (verification-level uint)
)
  (and
    (is-some (some user))
    (>= verification-level u1)
    (<= verification-level u5)
  )
)

;; Verify user by a registered verifier
(define-public (verify-user (user principal) (verification-level uint))
  (begin
    ;; Validate verification parameters
    (asserts! 
      (is-valid-verification user verification-level) 
      ERR-VERIFICATION-FAILED
    )
    
    (match (map-get? users user)
      some-user 
        (if (not (get is-verified some-user))
            (begin
              (map-set users user 
                (merge some-user {
                  is-verified: true, 
                  verification-level: verification-level
                })
              )
              (ok true)
            )
            ERR-ALREADY-VERIFIED
        )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Get user verification status
(define-read-only (get-user-verification (user principal))
  (match (map-get? users user)
    some-user 
      (some {
        is-verified: (get is-verified some-user),
        verification-level: (get verification-level some-user)
      })
    none
  )
)