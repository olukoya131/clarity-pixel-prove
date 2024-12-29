;; Define NFT token
(define-non-fungible-token pixel-photo uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-funds (err u103))

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var royalty-percentage uint u50) ;; 5% royalty

;; Data maps
(define-map photo-metadata uint {
    photographer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    camera-model: (string-ascii 50),
    location: (string-ascii 100),
    timestamp: uint,
    image-url: (string-ascii 200)
})

(define-map market-listings uint {
    price: uint,
    seller: principal
})

;; Mint new photo NFT
(define-public (mint-photo (title (string-ascii 100))
                          (description (string-ascii 500))
                          (camera-model (string-ascii 50))
                          (location (string-ascii 100))
                          (image-url (string-ascii 200)))
    (let ((token-id (+ (var-get last-token-id) u1)))
        (try! (nft-mint? pixel-photo token-id tx-sender))
        (map-set photo-metadata token-id {
            photographer: tx-sender,
            title: title,
            description: description,
            camera-model: camera-model,
            location: location,
            timestamp: block-height,
            image-url: image-url
        })
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; List photo for sale
(define-public (list-photo (token-id uint) (price uint))
    (let ((owner (unwrap! (nft-get-owner? pixel-photo token-id) err-not-token-owner)))
        (if (is-eq tx-sender owner)
            (begin
                (map-set market-listings token-id {
                    price: price,
                    seller: tx-sender
                })
                (ok true)
            )
            err-not-token-owner
        )
    )
)

;; Purchase photo
(define-public (purchase-photo (token-id uint))
    (let (
        (listing (unwrap! (map-get? market-listings token-id) err-listing-not-found))
        (price (get price listing))
        (seller (get seller listing))
        (metadata (unwrap! (map-get? photo-metadata token-id) err-listing-not-found))
        (photographer (get photographer metadata))
        (royalty (/ (* price (var-get royalty-percentage)) u1000))
    )
        (if (is-eq tx-sender seller)
            err-not-token-owner
            (begin
                ;; Transfer payment
                (try! (stx-transfer? price tx-sender seller))
                ;; Pay royalty to photographer if not the seller
                (if (not (is-eq seller photographer))
                    (try! (stx-transfer? royalty tx-sender photographer))
                    true
                )
                ;; Transfer NFT
                (try! (nft-transfer? pixel-photo token-id seller tx-sender))
                ;; Remove listing
                (map-delete market-listings token-id)
                (ok true)
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-photo-metadata (token-id uint))
    (map-get? photo-metadata token-id)
)

(define-read-only (get-listing (token-id uint))
    (map-get? market-listings token-id)
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)