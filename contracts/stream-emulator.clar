;; Arbitrum Streaming Emulator
;; A decentralized smart contract for simulating token streaming and time-based value distribution
;; with flexible allocation and verification mechanisms.

;; =======================================
;; Constants and Error Codes
;; =======================================
(define-constant contract-deployer tx-sender)

;; Error codes
(define-constant err-not-authorized (err u200))
(define-constant err-stream-not-found (err u201))
(define-constant err-stream-already-exists (err u202))
(define-constant err-invalid-stream-params (err u203))
(define-constant err-insufficient-balance (err u204))
(define-constant err-stream-completed (err u205))

;; Stream status constants
(define-constant stream-status-active u1)
(define-constant stream-status-completed u2)

;; =======================================
;; Data Maps and Variables
;; =======================================

;; Tracks individual token streams
(define-map token-streams
  {
    stream-id: uint,
    sender: principal
  }
  {
    recipient: principal,
    token-contract: principal,
    total-amount: uint,
    start-time: uint,
    end-time: uint,
    claimed-amount: uint,
    status: uint
  }
)

;; Tracks next stream ID
(define-map stream-count principal uint)

;; =======================================
;; Private Helper Functions
;; =======================================

;; Calculate next stream ID for a sender
(define-private (get-next-stream-id (sender principal))
  (default-to u1 (map-get? stream-count sender))
)

;; Update stream count for a sender
(define-private (increment-stream-count (sender principal))
  (let
    (
      (current-count (get-next-stream-id sender))
    )
    (map-set stream-count sender (+ current-count u1))
    current-count
  )
)

;; Validate stream parameters
(define-private (validate-stream-params 
                  (total-amount uint) 
                  (start-time uint) 
                  (end-time uint))
  (and 
    (> total-amount u0)
    (< start-time end-time)
  )
)

;; Calculate claimable amount at current time
(define-private (calculate-claimable-amount 
                  (total-amount uint)
                  (start-time uint)
                  (end-time uint)
                  (claimed-amount uint))
  (let
    (
      (current-time block-height)
      (total-duration (- end-time start-time))
      (elapsed-time (- current-time start-time))
    )
    (if (>= current-time end-time)
      (- total-amount claimed-amount)
      (if (> current-time start-time)
        (let
          (
            (proportional-amount 
              (/ (* total-amount elapsed-time) total-duration))
          )
          (- proportional-amount claimed-amount)
        )
        u0
      )
    )
  )
)

;; =======================================
;; Read-Only Functions
;; =======================================

;; Get stream details
(define-read-only (get-stream-details 
                    (stream-id uint) 
                    (sender principal))
  (map-get? token-streams {stream-id: stream-id, sender: sender})
)

;; Calculate claimable amount for a stream
(define-read-only (get-claimable-amount 
                    (stream-id uint) 
                    (sender principal))
  (let
    (
      (stream-data (unwrap! 
        (map-get? token-streams {stream-id: stream-id, sender: sender}) 
        (err err-stream-not-found)
      ))
    )
    (ok (calculate-claimable-amount 
          (get total-amount stream-data)
          (get start-time stream-data)
          (get end-time stream-data)
          (get claimed-amount stream-data)
        )
    )
  )
)

;; =======================================
;; Public Functions
;; =======================================

;; Create a new token stream
(define-public (create-stream 
                 (recipient principal)
                 (token-contract principal)
                 (total-amount uint)
                 (start-time uint)
                 (end-time uint))
  (let
    (
      (sender tx-sender)
      (stream-id (increment-stream-count sender))
    )
    ;; Validate input parameters
    (asserts! 
      (validate-stream-params total-amount start-time end-time) 
      (err err-invalid-stream-params)
    )

    ;; Create stream entry
    (map-set token-streams
      {stream-id: stream-id, sender: sender}
      {
        recipient: recipient,
        token-contract: token-contract,
        total-amount: total-amount,
        start-time: start-time,
        end-time: end-time,
        claimed-amount: u0,
        status: stream-status-active
      }
    )

    (ok stream-id)
  )
)

;; Claim tokens from a stream
(define-public (claim-stream-tokens (stream-id uint))
  (let
    (
      (sender tx-sender)
      (stream-data (unwrap! 
        (map-get? token-streams {stream-id: stream-id, sender: sender}) 
        (err err-stream-not-found)
      ))
      (claimable-amount 
        (unwrap-panic 
          (get-claimable-amount stream-id sender)
        )
      )
    )
    ;; Validate claim
    (asserts! (> claimable-amount u0) (err err-insufficient-balance))
    (asserts! 
      (not (is-eq (get status stream-data) stream-status-completed)) 
      (err err-stream-completed)
    )

    ;; Update stream data
    (map-set token-streams
      {stream-id: stream-id, sender: sender}
      (merge stream-data {
        claimed-amount: (+ (get claimed-amount stream-data) claimable-amount),
        status: (if (>= (get claimed-amount stream-data) (get total-amount stream-data))
                  stream-status-completed
                  stream-status-active)
      })
    )

    ;; TODO: Add actual token transfer logic
    (ok claimable-amount)
  )
)