# Gaming NFT Marketplace and DAO Platform

A decentralized marketplace for gaming NFTs built on Stacks blockchain, featuring DAO governance, staking mechanisms, and secure trading functionality.

## Overview

The Gaming NFT Marketplace is a comprehensive platform that enables:
- Minting and trading of gaming NFTs
- Decentralized governance through DAO mechanisms
- Staking and rewards system
- Secure marketplace transactions
- Creator commissions and platform fees

## Technical Architecture

### Core Components

1. **NFT Management**
   - Customizable NFT minting with editions
   - Metadata URI storage
   - Commission rate configuration (up to 25%)
   - Authentication and verification system

2. **Marketplace Features**
   - Secure listing creation
   - Direct purchase functionality
   - Platform fee structure (2%)
   - Time-bound listings
   - Optional auction support

3. **DAO Governance**
   - Proposal creation and voting
   - Stake-based governance
   - Time-locked voting periods
   - Quorum requirements

4. **Token System**
   - Game Items (NFT editions)
   - DAO Tokens (governance)
   - Platform Credits (utility)

### Security Features

1. **Input Validation**
   - NFT ID validation
   - Price and quantity bounds checking
   - Ownership verification
   - Balance verification

2. **Access Control**
   - Administrative functions protection
   - System-wide pause mechanism
   - Emergency shutdown capability
   - Account restriction system

3. **Safe Transfers**
   - Atomic transactions
   - Balance checks
   - Overflow prevention
   - Locked token handling

## Smart Contract Interface

### Constants

```clarity
MAX-COMMISSION-RATE: u250 (25.0%)
MARKETPLACE-FEE: u20 (2.0%)
BASE-PRICE: u1000000 (in micro-STX)
LOCK-PERIOD: u144 (~24 hours)
VOTE-DURATION: u1008 (~7 days)
```

### Core Functions

1. **NFT Operations**
```clarity
(mint-nft (asset-uri (string-utf8 256)) (commission-rate uint) (total-editions uint))
```
- Creates new NFT with specified editions
- Sets creator commission rate
- Stores asset metadata URI

2. **Marketplace Functions**
```clarity
(create-listing (nft-id uint) (quantity uint) (price uint))
(buy-nft (nft-id uint))
```
- List NFTs for sale
- Purchase listed NFTs

3. **Administrative Functions**
```clarity
(set-system-lock (new-state bool))
(set-marketplace-wallet (new-wallet principal))
(activate-emergency-mode)
```

## Error Handling

The contract implements comprehensive error codes:

| Code | Description |
|------|-------------|
| ERR-UNAUTHORIZED | Action requires higher privileges |
| ERR-SYSTEM-LOCKED | System is currently paused |
| ERR-BAD-INPUT | Invalid input parameters |
| ERR-MISSING | Requested item not found |
| ERR-LOW-BALANCE | Insufficient balance for operation |

## Usage Guide

### For NFT Creators

1. Mint new NFTs:
   ```clarity
   (contract-call? .gaming-nft-marketplace mint-nft 
       "https://asset.uri/metadata.json" 
       u100  ;; 10% commission
       u1000 ;; 1000 editions
   )
   ```

2. List NFTs for sale:
   ```clarity
   (contract-call? .gaming-nft-marketplace create-listing 
       u1    ;; NFT ID
       u10   ;; Quantity
       u1000000 ;; Price in micro-STX
   )
   ```

### For Buyers

1. Purchase NFTs:
   ```clarity
   (contract-call? .gaming-nft-marketplace buy-nft u1)
   ```

### For DAO Participants

1. Stake tokens:
   ```clarity
   ;; Minimum stake: u100000000
   (contract-call? .gaming-nft-marketplace stake-tokens u100000000)
   ```

2. Participate in governance:
   ```clarity
   (contract-call? .gaming-nft-marketplace vote u1 true)
   ```

## Development Setup

1. Requirements:
   - Clarity CLI
   - Node.js (for testing)
   - Stacks blockchain local development environment

2. Local deployment:
   ```bash
   clarinet contract deploy gaming-nft-marketplace
   ```

3. Testing:
   ```bash
   clarinet test
   ```

## Security Considerations

1. **Rate Limits**
   - Maximum commission rate: 25%
   - Platform fee: 2%
   - Minimum listing price enforced

2. **Time Locks**
   - NFT transfers can be time-locked
   - DAO proposals have fixed voting periods
   - Account restrictions have maximum durations

3. **Balance Protection**
   - All operations check for sufficient balances
   - Overflow protection on mathematical operations
   - Atomic transactions for marketplace operations

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Create a Pull Request

