# StackSpot Contracts

A decentralized lottery and pot system built on the Stacks blockchain, featuring a comprehensive suite of smart contracts that enable fair, transparent, and verifiable random number generation for lottery mechanics.

## 🎯 Project Overview

StackSpot is a blockchain-based lottery platform that allows users to participate in pots (lottery pools) where participants contribute STX tokens and a winner is randomly selected to receive the accumulated pot value. The system emphasizes fairness through verifiable random functions (VRF) and transparency through on-chain logging of all activities.

## 🏗️ Architecture

The project consists of 7 interconnected smart contracts that work together to create a complete lottery ecosystem:

### Core Contracts

1. **`stackpot.clar`** - Main lottery contract
2. **`stackpot-pots.clar`** - NFT-based pot registry
3. **`stackpot-vrf.clar`** - Verifiable Random Function implementation
4. **`sim-pox.clar`** - Simplified Proof of Transfer (PoX) simulation

### Supporting Contracts

5. **`stackpot-pot-participants.clar`** - Participant logging
6. **`stackpot-pot-winners.clar`** - Winner logging
7. **`stackpot-pot-trait.clar`** - Interface trait definition

## 📋 Contract Details

### 1. `stackpot.clar` - Main Lottery Contract

The heart of the StackSpot system, this contract manages the entire lottery lifecycle.

#### Key Features:
- **Pot Management**: Handles participant registration, pot locking, and winner selection
- **Configuration System**: Flexible settings for pot parameters
- **Random Selection**: Integrates with VRF for fair winner selection
- **Reward Distribution**: Automatically distributes winnings and participant refunds

#### Core Functions:

**Configuration Management:**
- `set-config(config-key, value)` - Update pot configuration (max participants, fees, etc.)
- `set-pot-fee(new-fee)` - Set the platform fee for pot creation
- `get-configs()` - Retrieve current configuration settings

**Participation:**
- `join-pot(amount, participant)` - Allow users to join a pot with a specified amount
- `delegate-to-pot(amount, participant)` - Internal function handling participant registration

**Pot Operations:**
- `start-jackpot()` - Initialize a new pot round
- `reward-pot-winner()` - Select winner and distribute rewards
- `get-pot-participants()` - Retrieve list of all participants
- `get-pot-value()` - Get current total pot value

**Random Selection:**
- `get-random-digit(participant-count)` - Generate random winner index using VRF

#### Configuration Parameters:
- **Max Participants**: Up to 100 participants per pot
- **Min Amount**: Minimum contribution required (default: 100 microSTX)
- **Pot Fee**: Platform fee for pot creation (default: 100,000 microSTX)
- **Reward Token**: Token type for rewards (default: "sbtc")

#### Security Features:
- **Locking Mechanism**: Prevents new participants during pot execution
- **Duplicate Prevention**: Ensures one participation per address
- **Balance Validation**: Verifies sufficient STX balance before participation
- **Authorization Checks**: Only pot owner can modify configurations

### 2. `stackpot-pots.clar` - NFT Pot Registry

Manages pot ownership and registration through NFT tokens, providing a unique identifier for each pot.

#### Key Features:
- **NFT Minting**: Each pot gets a unique NFT token
- **Ownership Tracking**: Maps pot owners to their NFT tokens
- **Fee Management**: Handles platform fees for pot creation
- **Event Logging**: Logs pot registration and winner events

#### Core Functions:

**Pot Registration:**
- `register-pot(pot-values)` - Register a new pot and mint NFT
- `mint(recipient)` - Mint NFT for pot owner
- `get-owner-token-id(owner)` - Get NFT ID for pot owner

**NFT Management:**
- `transfer(token-id, sender, recipient)` - Transfer pot ownership
- `get-owner(token-id)` - Get current owner of pot NFT
- `get-token-uri(token-id)` - Get metadata URI (returns none)

**Event Logging:**
- `log-winner(winner-values)` - Log winner information
- `log-participant(participant-values)` - Log participant information

#### Fee Structure:
- **Platform Fee**: Required STX payment for pot creation
- **Treasury Management**: Automatic fee collection to platform treasury

### 3. `stackpot-vrf.clar` - Verifiable Random Function

Implements cryptographically secure random number generation using blockchain data.

#### Key Features:
- **Blockchain-Based Randomness**: Uses burn block headers for entropy
- **Verifiable Results**: Anyone can verify the randomness source
- **Deterministic Output**: Same inputs always produce same results
- **Tamper-Proof**: Cannot be manipulated by miners or participants

#### Core Functions:

**Random Generation:**
- `get-random-uint-at-block(blockHeight)` - Generate random number from specific block
- `lower-16-le(input)` - Extract lower 16 bytes in little-endian format

**Utility Functions:**
- `buff-to-u8(byte)` - Convert buffer to uint8
- `add-and-shift-uint-le(idx, input)` - Helper for buffer-to-uint conversion

#### Randomness Process:
1. **Block Hash**: Uses burn block header hash as entropy source
2. **Sender Hash**: Incorporates transaction sender for additional randomness
3. **Merging**: Combines block hash and sender hash
4. **Hashing**: Applies SHA256 to merged data
5. **Extraction**: Takes lower 16 bytes for final random number

### 4. `sim-pox.clar` - Simplified PoX Simulation

A simplified implementation of Stacks' Proof of Transfer (PoX) mechanism for testing and simulation purposes.

#### Key Features:
- **Stacking Simulation**: Mimics STX stacking behavior
- **Reward Cycles**: Manages reward cycle calculations
- **Delegation Support**: Handles stacking delegation
- **Rejection Mechanism**: Allows PoX rejection voting

#### Core Functions:

**Stacking Operations:**
- `stack-stx(amount-ustx, pox-addr, start-burn-ht, lock-period)` - Lock STX for stacking
- `delegate-stx(amount-ustx, delegate-to, until-burn-ht, pox-addr)` - Delegate stacking rights
- `reject-pox()` - Vote to reject PoX for a cycle

**Information Retrieval:**
- `get-pox-info()` - Get current PoX parameters
- `get-stacker-info(stacker)` - Get stacker's current status
- `can-stack-stx(pox-addr, amount-ustx, first-reward-cycle, num-cycles)` - Check stacking eligibility

#### Configuration:
- **Min Lock Period**: 1 reward cycle
- **Max Lock Period**: 12 reward cycles
- **Stacking Thresholds**: Dynamic based on liquid supply
- **Rejection Fraction**: 25% threshold for PoX rejection

### 5. `stackpot-pot-participants.clar` - Participant Logging

Simple contract for logging participant information and activities.

#### Core Functions:
- `log-participant(participant-values)` - Log participant details including:
  - Pot ID
  - Participant ID
  - Participant address
  - Contribution amount
  - Timestamp

### 6. `stackpot-pot-winners.clar` - Winner Logging

Handles logging of winner information and pot results.

#### Core Functions:
- `log-winner(winner-values)` - Log comprehensive winner data including:
  - Pot configuration details
  - Winner information
  - Reward amounts
  - Block timestamps
  - Round statistics

### 7. `stackpot-pot-trait.clar` - Interface Definition

Defines the standard interface that all pot contracts must implement.

#### Required Functions:
- `join-pot(uint) -> (response bool uint)` - Join a pot with specified amount
- `reward-pot-winner() -> (response bool uint)` - Execute winner selection
- `get-pot-participants() -> (response (list 100 principal) (list 100 principal))` - Get participant list
- `get-pot-value() -> (response uint uint)` - Get current pot value
- `get-pot-config() -> (response {cycles: uint, fee: uint, max-participants: uint} {cycles: uint, fee: uint, max-participants: uint})` - Get pot configuration

## 🔄 System Workflow

### 1. Pot Creation
1. User calls `register-pot()` in `stackpot-pots.clar`
2. Platform fee is collected
3. NFT is minted to represent pot ownership
4. Pot is registered in the system

### 2. Participant Registration
1. Users call `join-pot()` in `stackpot.clar`
2. System validates participant eligibility
3. STX is transferred to pot treasury
4. Participant is added to pot participants list
5. Pot value is updated

### 3. Winner Selection
1. Pot owner calls `reward-pot-winner()`
2. System generates random number using VRF
3. Winner is selected based on random index
4. Rewards are distributed:
   - 99% to winner (or 100% if claimer is winner)
   - 1% to claimer (if different from winner)
5. All participants receive their principal back
6. Winner and participant data is logged
7. Pot is reset for next round

## 🛡️ Security Features

### Randomness Security
- **Verifiable Random Function**: Uses blockchain data for tamper-proof randomness
- **Multiple Entropy Sources**: Combines block hash and sender information
- **Deterministic Verification**: Anyone can verify the randomness source

### Access Control
- **Owner-Only Operations**: Only pot owners can modify configurations
- **Participant Validation**: Strict checks for participant eligibility
- **Locking Mechanism**: Prevents manipulation during pot execution

### Financial Security
- **Balance Verification**: Ensures sufficient funds before participation
- **Automatic Refunds**: Participants always get their principal back
- **Fee Transparency**: Clear fee structure and collection

## 🧪 Testing

The project includes comprehensive test suites for all contracts:

- **`jackpot.test.ts`** - Main lottery functionality tests
- **`sim-pox.test.ts`** - PoX simulation tests
- **`stackpot-pot-participants.test.ts`** - Participant logging tests
- **`stackpot-pot-trait.test.ts`** - Interface compliance tests
- **`stackpot-pot-winners.test.ts`** - Winner logging tests
- **`stackpot-pots.test.ts`** - Pot registry tests
- **`stackpot-vrf.test.ts`** - Random function tests

### Running Tests
```bash
npm test                    # Run all tests
npm run test:report        # Run with coverage report
npm run test:watch         # Watch mode for development
```

## 🚀 Getting Started

### Prerequisites
- Node.js and npm
- Clarinet SDK
- Stacks blockchain access

### Installation
```bash
npm install
```

### Development
```bash
# Start Clarinet console
clarinet console

# Run tests
npm test

# Watch for changes
npm run test:watch
```

## 📊 Configuration

### Default Settings
- **Max Participants**: 100
- **Min Amount**: 100 microSTX
- **Pot Fee**: 100,000 microSTX
- **Reward Token**: "sbtc"
- **Platform Address**: ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5

### Customization
All parameters can be modified through the configuration system, allowing for flexible pot setups based on different use cases and requirements.

## 🔗 Contract Dependencies

The contracts are designed to work together seamlessly:
- `stackpot.clar` depends on `stackpot-pots.clar`, `stackpot-vrf.clar`
- `stackpot-pots.clar` depends on `stackpot-pot-participants.clar`, `stackpot-pot-winners.clar`
- All pot contracts implement `stackpot-pot-trait.clar` interface

## 📝 License

This project is licensed under the ISC License.

## 🤝 Contributing

Contributions are welcome! Please ensure all tests pass and follow the existing code style.

## ⚠️ Disclaimer

This is a lottery system that involves financial transactions. Users should understand the risks involved and use at their own discretion. The system is designed for transparency and fairness, but users should always verify the contract behavior before participating.
