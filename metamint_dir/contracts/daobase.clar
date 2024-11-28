;; Gaming NFT Marketplace and DAO Platform Contract

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u1000))
(define-constant ERR-SYSTEM-LOCKED (err u1001))
(define-constant ERR-BAD-INPUT (err u1002))
(define-constant ERR-MISSING (err u1003))
(define-constant ERR-ACCESS-DENIED (err u1004))
(define-constant ERR-LOW-BALANCE (err u1005))
(define-constant ERR-DUPLICATE (err u1006))
(define-constant ERR-INVALID-STATE (err u1007))
(define-constant ERR-OPERATION-FAILED (err u1008))
(define-constant ERR-TIMEOUT (err u1009))
(define-constant ERR-INVALID-NFT (err u1011))

;; Constants
(define-constant CONTRACT-ADMIN tx-sender)
(define-constant MAX-COMMISSION-RATE u250) ;; 25.0%
(define-constant MARKETPLACE-FEE u20) ;; 2.0%
(define-constant BASE-PRICE u1000000) ;; in micro-STX
(define-constant LOCK-PERIOD u144) ;; ~24 hours in blocks
(define-constant VOTE-DURATION u1008) ;; ~7 days in blocks
(define-constant MIN-GOVERNANCE-STAKE u100000000) ;; Minimum stake requirement
(define-constant REWARDS-PERIOD u144) ;; ~24 hours in blocks
(define-constant MAX-NFT-ID u1000000) ;; Maximum valid NFT ID
(define-constant MIN-NFT-ID u1) ;; Minimum valid NFT ID

;; Data Variables
(define-data-var total-nfts uint u0)
(define-data-var total-votes uint u0)
(define-data-var system-locked bool false)
(define-data-var marketplace-wallet principal CONTRACT-ADMIN)
(define-data-var total-staked-tokens uint u0)
(define-data-var last-rewards-cycle uint u0)
(define-data-var total-marketplace-revenue uint u0)
(define-data-var emergency-mode-active bool false)

;; Fungible Tokens
(define-fungible-token game-items)
(define-fungible-token dao-token)
(define-fungible-token platform-credits)

;; Data Maps
(define-map nfts
    {id: uint}
    {owner: principal,
     creator: principal,
     asset-uri: (string-utf8 256),
     commission-rate: uint,
     total-editions: uint,
     tradeable: bool,
     mint-block: uint,
     total-sales: uint,
     authenticated: bool})

(define-map market-entries
    {nft-id: uint}
    {price: uint,
     vendor: principal,
     valid-until: uint,
     quantity: uint,
     auction-info: (optional {
         initial-price: uint,
         reserve-price: uint,
         top-bidder: (optional principal),
         bid-increment: uint
     })})

(define-map nft-balances
    {nft-id: uint, owner: principal}
    {quantity: uint,
     locked-until: uint})

(define-map governance-stakes
    {participant: principal}
    {amount: uint,
     locked-until: uint,
     reward-balance: uint,
     last-reward-claim: uint})

(define-map dao-votes
    {id: uint}
    {creator: principal,
     subject: (string-utf8 256),
     details: (string-utf8 1024),
     start-block: uint,
     end-block: uint,
     completed: bool,
     support-count: uint,
     oppose-count: uint,
     proposal: (string-utf8 256),
     quorum: uint})

(define-map reward-distribution
    {cycle: uint}
    {pool-size: uint,
     completed: bool})

;; Input Validation Functions
(define-private (validate-nft-id (nft-id uint))
    (begin
        (asserts! (and 
            (>= nft-id MIN-NFT-ID)
            (<= nft-id MAX-NFT-ID)) 
            ERR-INVALID-NFT)
        
        (asserts! (<= nft-id (var-get total-nfts)) 
            ERR-INVALID-NFT)
        
        (match (map-get? nfts {id: nft-id})
            nft (ok nft-id)
            ERR-MISSING)))

(define-private (verify-nft-owner (nft-id uint) (owner principal))
    (match (map-get? nfts {id: nft-id})
        nft (ok (is-eq (get owner nft) owner))
        ERR-MISSING))

;; Helper Functions
(define-private (check-system-status)
    (if (var-get system-locked)
        ERR-SYSTEM-LOCKED
        (ok true)))

;; Safe Transfer Implementation
(define-private (safe-transfer-nft (nft-id uint) (from principal) (to principal) (amount uint))
    (let ((validated-nft-id (try! (validate-nft-id nft-id))))
        (asserts! (is-some (map-get? nfts {id: validated-nft-id})) ERR-INVALID-NFT)
        (let ((sender-balance (unwrap! (map-get? nft-balances 
                {nft-id: validated-nft-id, owner: from})
                ERR-MISSING))
              (receiver-balance (default-to 
                {quantity: u0, locked-until: u0}
                (map-get? nft-balances {nft-id: validated-nft-id, owner: to}))))
            
            (asserts! (>= (get quantity sender-balance) amount) ERR-LOW-BALANCE)
            (asserts! (< (+ (get quantity receiver-balance) amount) (pow u2 u64)) ERR-BAD-INPUT)
            
            (map-set nft-balances
                {nft-id: validated-nft-id, owner: from}
                {quantity: (- (get quantity sender-balance) amount),
                 locked-until: (get locked-until sender-balance)})
            
            (map-set nft-balances
                {nft-id: validated-nft-id, owner: to}
                {quantity: (+ (get quantity receiver-balance) amount),
                 locked-until: (get locked-until receiver-balance)})
            
            (ok true))))


;; Core NFT Functions
(define-public (mint-nft
    (asset-uri (string-utf8 256))
    (commission-rate uint)
    (total-editions uint))
    (begin
        (try! (check-system-status))
        (asserts! (>= (len asset-uri) u10) ERR-BAD-INPUT)
        (asserts! (<= commission-rate MAX-COMMISSION-RATE) ERR-BAD-INPUT)
        (asserts! (and 
            (> total-editions u0)
            (< total-editions (pow u2 u64))) ERR-BAD-INPUT)
        
        (let ((nft-id (+ (var-get total-nfts) u1)))
            (try! (validate-nft-id nft-id))
            (try! (ft-mint? game-items total-editions tx-sender))
            (map-set nfts
                {id: nft-id}
                {owner: tx-sender,
                 creator: tx-sender,
                 asset-uri: asset-uri,
                 commission-rate: commission-rate,
                 total-editions: total-editions,
                 tradeable: false,
                 mint-block: u0, ;; Replace with appropriate method to get block height
                 total-sales: u0,
                 authenticated: false})
            
            (map-set nft-balances
                {nft-id: nft-id, owner: tx-sender}
                {quantity: total-editions,
                 locked-until: u0})
            
            (var-set total-nfts nft-id)
            (ok nft-id))))

;; Marketplace Functions
(define-public (create-listing
    (nft-id uint)
    (quantity uint)
    (price uint))
    (let 
        ((validated-nft-id (try! (validate-nft-id nft-id))))
        (begin
            (try! (check-system-status))
            
            (asserts! (unwrap! (verify-nft-owner validated-nft-id tx-sender) ERR-MISSING)
                ERR-UNAUTHORIZED)
            
            (asserts! (and 
                (>= price BASE-PRICE)
                (< price (pow u2 u64)))
                ERR-BAD-INPUT)
            
            (let ((balance (unwrap! (map-get? nft-balances 
                    {nft-id: validated-nft-id, owner: tx-sender})
                    ERR-MISSING)))
                
                (asserts! (and
                    (>= (get quantity balance) quantity)
                    (> quantity u0)
                    (< quantity (pow u2 u64)))
                    ERR-BAD-INPUT)
                
                (asserts! (>= u0 (get locked-until balance)) 
                    ERR-INVALID-STATE)
                
                (map-set market-entries
                    {nft-id: validated-nft-id}
                    {price: price,
                     vendor: tx-sender,
                     valid-until: (+ u0 u1440), 
                     quantity: quantity,
                     auction-info: none})
                (ok true)))))

;; Purchase Function
(define-public (buy-nft (nft-id uint))
    (let ((validated-nft-id (try! (validate-nft-id nft-id))))
        (begin
            (try! (check-system-status))
            
            (asserts! (and (>= validated-nft-id MIN-NFT-ID) 
                           (<= validated-nft-id MAX-NFT-ID)) 
                      ERR-INVALID-NFT)
            
            (let ((listing (unwrap! (map-get? market-entries {nft-id: validated-nft-id}) 
                    ERR-MISSING))
                  (price (get price listing))
                  (vendor (get vendor listing))
                  (quantity (get quantity listing)))
                
                (asserts! (<= u0 (get valid-until listing)) ERR-TIMEOUT) 
                (asserts! (not (is-eq tx-sender vendor)) ERR-BAD-INPUT)
                
                (let ((balance (stx-get-balance tx-sender)))
                    (asserts! (and 
                        (>= balance price)
                        (>= price BASE-PRICE)
                        (< price (pow u2 u64)))
                        ERR-LOW-BALANCE))
                
                (let ((platform-fee (/ (* price MARKETPLACE-FEE) u1000))
                      (vendor-payment (- price platform-fee)))
                    
                    (try! (stx-transfer? platform-fee tx-sender (var-get marketplace-wallet)))
                    (try! (stx-transfer? vendor-payment tx-sender vendor))
                    
                    (match (map-get? nft-balances 
                            {nft-id: validated-nft-id, owner: vendor})
                        vendor-balance 
                            (begin
                                (asserts! (>= (get quantity vendor-balance) quantity) 
                                    ERR-LOW-BALANCE)
                                (asserts! (is-some (map-get? nfts {id: validated-nft-id})) 
                                          ERR-INVALID-NFT)
                                (try! (safe-transfer-nft validated-nft-id vendor tx-sender quantity))
                                (map-delete market-entries {nft-id: validated-nft-id})
                                (ok true))
                        ERR-MISSING))))))

;; Admin Functions
(define-public (set-system-lock (new-state bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMIN) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq new-state (var-get system-locked))) ERR-BAD-INPUT)
        (var-set system-locked new-state)
        (ok true)))

(define-public (set-marketplace-wallet (new-wallet principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMIN) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq new-wallet (var-get marketplace-wallet))) ERR-BAD-INPUT)
        (ok (var-set marketplace-wallet new-wallet))))

(define-public (activate-emergency-mode)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMIN) ERR-UNAUTHORIZED)
        (var-set emergency-mode-active true)
        (var-set system-locked true)
        (ok true)))

