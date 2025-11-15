# StackSpot Contracts

StackSpot is a lottery-style staking platform for Stacks that coordinates STX delegation, sBTC yield-sharing, and on-chain logging. This repository contains two Clarinet workspaces:

- `simnet/` – authoritative simulation environment and core contracts used for day-to-day development.
- `beta/` – staging copy meant for packaging/bulk deployments to testnet; contracts mirror the simnet versions but are tuned for deployment drills. Keep documentation about beta concise: it inherits functionality from simnet and is only surfaced when preparing release bundles.

The sections below document every contract that ships inside `simnet/contracts` and give high-level notes for the beta set and the external protocol dependencies StackSpot leans on.

---

## Project Summary

StackSpot orchestrates decentralized “pots” (jackpot-style investment pools) where participants contribute STX, delegate those funds into PoX cycles to earn BTC-denominated yield (paid in sBTC), and later share the proceeds according to on-chain, auditable rules. Every pot is represented by a non-transferable NFT in the `stackspots` registry, gated by an admin/audit layer, and instrumented with extensive logging so operators can trace deployments, reward claims, and participant refunds.

**Lifecycle overview**
- **Pot onboarding**: Admins or approved community members register new pot contracts; a fee is collected, metadata is logged, and the pot initializes with verified code hashes.
- **Participant intake**: Users join pots through contracts that implement `stackspot-trait`, passing balance/eligibility checks before their STX is transferred to the pot treasury.
- **Delegation & earning**: Treasury funds can be delegated to PoX pools (via `stackspot-distribute` + `sim-pox-4` helpers) to accrue yield while the join window is locked.
- **Reward release**: After the configured reward cycle completes, the jackpot contract selects winners through VRF, `stackspots` refunds all principals, and `stackspot-distribute` splits sBTC rewards across platform, owner, starter, claimer, and winner.
- **Telemetry & compliance**: Registry and winner contracts emit structured buffers for every deployment and payout, simplifying off-chain analytics, auditing, and compliance reporting.

**Key platform capabilities**
- NFT-based pot registry that ties each treasury to a verifiable deployment record.
- Configurable jackpot implementation with participant caps, minimum deposits, lock toggles, and VRF-based randomness.
- Treasury dispatcher that automates both STX refunds and sBTC reward distribution, including configurable royalty slices.
- Admin/audit layer that separates governance (who can deploy) from compliance (which contracts are allowed to touch funds).
- PoX delegation tooling (simulated in `simnet/`) so pots can compound yield while awaiting draws.
- Comprehensive logging and memoized token transfers for transparent post-trade analysis.

---

## Repository Map

```
stackspot-contracts/
├── README.md
├── simnet/
│   ├── Clarinet.toml
│   ├── contracts/
│   │   ├── stackspot-*.clar
│   │   ├── sbtc-*.clar
│   │   ├── sim-pox-4.clar
│   │   └── sim-pox4-multi-pool-v1.clar
│   └── tests, deployments, etc.
└── beta/
    └── contracts/ (staging copies of the StackSpot suite)
```

Use absolute paths (e.g. `/mnt/d/.../simnet/contracts/stackspots.clar`) when scripting interactions.

---

## Simnet Contract Suite

### Platform Governance & Registry Layer

#### `stackspot-admin.clar`
- **Purpose**: Maintains the allow-list of platform administrators and toggles whether public users can deploy pots.
- **Key state**: `admins` map, `public-pot-deploy` flag, implicit `primary-admin` (set to deployer).
- **Important entrypoints**:
  - `add-update-admin-status(principal, bool)` – only the primary admin can grant or revoke admin rights.
  - `update-public-pot-deploy-status(bool)` – flip the public deployment gate; requires existing admin.
  - `is-admin()` and `can-deploy-pot()` read-only helpers consumed by other contracts (e.g., `stackspots`, `stackspot-audited-contracts`).

#### `stackspot-audited-contracts.clar`
- **Purpose**: Tracks which pot contracts passed audits before they can distribute rewards or delegate treasury control.
- **Flow**:
  - Admins (validated via `stackspot-admin`) call `update-audited-contract(<stackspot-trait>, bool)` or `remove-audited-contract`.
  - Consumers such as `stackspots` and `stackspot-distribute` require `is-audited-contract` to be true before dispatching rewards or delegating pooled STX.

#### `stackspots.clar`
- **Role**: NFT-based registry for every pot contract deployed on StackSpot.
- **Highlights**:
  - Implements SIP-009 NFT `stackpot-pot`.
  - `register-pot(pot-values)` mints the next NFT, transfers the platform fee, logs deployment metadata via `stackspot-registry`, and guards against non-audited or underfunded deployers.
  - `mint(principal)` is fee-gated and non-transferable – NFT ownership encodes pot identity and enforces a single contract per pot.
  - Dispatch helpers (`dispatch-principals`, `dispatch-rewards`, `delegate-treasury`) enforce that only the registered pot contract can trigger settlement routines in `stackspot-distribute`.

#### `stackspot-registry.clar`
- **Purpose**: Thin logging shim invoked by `stackspots` to emit pot-level telemetry (`log-pot`).
- **Security**: Accepts calls only from the `stackspots` contract and prints structured pot data for off-chain ingestion.

#### `stackspot-winners.clar`
- **Purpose**: Persists settlement telemetry each time rewards are dispatched.
- **Entry point**: `log-winner(buff)` – callable solely by `stackspot-distribute`; prints the encoded reward breakdown that includes participants, yields, claimer/starter splits, and cycle metadata.

---

### Pot Implementation & Runtime Helpers

#### `stackspot-trait.clar`
- **Description**: Trait that every StackSpot-compatible pot must implement.
- **Surface area**: Read-only getters for admin, treasury, participants, yield, configuration (cycle timings, token info, min/max contributions) plus helpers (`get-by-id-helper`, `get-pot-details`, etc.).
- **Usage**: Enforced by `stackspots`, `stackspot-distribute`, and `stackspot-audited-contracts` to keep pot contracts interchangeable.

#### `stackspot-jackpot.clar`
- **Role**: Reference pot implementation that manages the full jackpot lifecycle (join, lock, delegate to pools, and payout).
- **Key mechanics**:
  - Tracks participant slots via `pot-participants-by-*` maps and enforces uniqueness, balance checks, min/max thresholds, and join window locking (`locked` flag).
  - Uses VRF data to select winners (`get-random-index`) and records starter/claimer principals for royalty splits.
  - `start-stackspot-jackpot(<stackspot-trait>)` delegates treasury custody to `stackspots`, locks participation, and records the starter.
  - `claim-pot-reward(<stackspot-trait>)` orchestrates: compute VRF winner → refund principals via `stackspots.dispatch-principals` → trigger reward distribution → emit full round telemetry.
  - Config constants (min amount, max participants, cycle info, contract hash) live at the foot of the file and are registered with `stackspots` on deploy.

#### `stackspot-distribute.clar`
- **Purpose**: Treasury operations contract responsible for refunding principals, splitting sBTC rewards, and delegating pooled STX into PoX.
- **Notable entrypoints**:
  - `dispatch-principals(<stackspot-trait>)` – called by `stackspots`; iterates over participants and transfers their principal using STX memos for provenance. Validates pot treasury ownership and caller.
  - `dispatch-rewards(<stackspot-trait>)` – uses `sbtc-token` to transfer yield to platform, pot owner, starter, claimer, and winner (5%, 90%, etc.). Requires that claim windows are open (`validate-can-claim-pot`) and pot contract is audited.
  - `delegate-treasury(<stackspot-trait>, principal)` – during the join window, allows audited pots to signal delegation into PoX pools (wiring to `sim-pox4-multi-pool-v1` when uncommented).
  - Auxiliary read-onlys `get-pool-config`, `validate-can-pool-pot`, and `validate-can-claim-pot` are derived from `sim-pox-4`.

#### `stackspot-vrf.clar`
- **Functionality**: Burn-block-anchored VRF harness used both directly (e.g., `stackspot-jackpot`) and by helper contracts.
- **Workflow**:
  1. Fetch burn header hash (`get-burn-block-info?`).
  2. Concatenate with tx-sender principal.
  3. Hash and extract lower 16 bytes (little-endian) to produce a deterministic random uint.
  - Includes buffer utilities (`buff-to-u8`, `lower-16-le`, `generate-list`) for participant shuffling and randomness derivations.

---

### sBTC & PoX Dependencies (Support Contracts)

These contracts are not considered StackSpot core logic but are necessary dependencies for simnet execution. Be brief when referencing them in other docs; summarize only the essentials.

1. **`sbtc-token.clar`** – SIP-010 compatible fungible token with bifurcated liquid/locked supplies. Provides protocol-only mint/burn/lock entrypoints guarded by `sbtc-registry`. Also exposes a batch `transfer-many` flow and metadata getters.
2. **`sbtc-registry.clar`** – Governance contract that tracks active protocol roles (governance, deposit, withdrawal), manages withdrawal/deposit request logs, signer rotations, and enforces role-based authentication used by `sbtc-token`.
3. **`sim-pox-4.clar`** – Full PoX-4 simulation straight from Stacks 2.1 specs. StackSpot reads reward cycle data to know when delegation is allowed and uses the helper functions when delegating pooled STX. (The contract is long; treat it as the authoritative PoX engine for simnet.)
4. **`sim-pox4-multi-pool-v1.clar`** – Self-service stacking pool wrapper around `sim-pox-4` that automates delegation, partial commits, and cycle extensions for multiple users. StackSpot references it inside `stackspot-distribute.delegate-treasury` (call commented in simnet) as a future hook for multi-signer pools.

Although these four files live beside the StackSpot suite, they should be described as dependencies when communicating to integrators—they model how STX and sBTC move but are not modified frequently by the StackSpot team.

---

## Beta Contracts (Deployment Prep)

The `beta/contracts` directory contains trimmed copies of the StackSpot contracts (admin, audited-contracts, distribute, trait, vrf, winners, stackspots, and `stackspot-registery.clar`, which is the same logger with a historical spelling). They exist so we can stage Clarinet projects for bulk deployment on testnet:

- **No new logic** is introduced in beta; we simply mirror the simnet code and adjust metadata or network settings during release candidates.
- Documentation for beta should always reference the simnet descriptions above; only mention beta when describing release processes (e.g., "copy simnet contracts to beta, run Clarinet for testnet addresses, deploy as a bundle").

---

## System Workflow Recap

1. **Deployment**
   - Admins register audited pot contracts through `stackspots.register-pot`, which mints a non-transferable NFT and records metadata in `stackspot-registry`.
2. **Participation**
   - Users interact with the pot implementation (e.g., `stackspot-jackpot.join-pot`). Contributions are validated and transferred into the pot treasury (the contract principal).
3. **Stacking / Delegation**
   - Pot owners (or automation) trigger `start-stackspot-jackpot`, which delegates STX custody to `stackspots` and optionally further to PoX pools (`stackspot-distribute.delegate-treasury`) while locking the join window.
4. **Settlement**
   - After reward release, anyone can call `claim-pot-reward`. This sets claimer/final state, dispatches principal refunds, distributes sBTC rewards, and logs telemetry in `stackspot-winners`.
5. **Audit & Governance**
   - Admin contracts gate who can deploy, when public deployments are open, and which pots are considered audited before treasury actions proceed.

---

## Development & Testing

The Clarinet workspace under `simnet/` holds TypeScript tests (Vitest) that cover the jackpot flow, registry logging, VRF outputs, and PoX integrations. Typical workflow:

```bash
cd /mnt/d/Csmith/Documents/React-Projects/stackspot-contracts/simnet
npm install
npm test          # Runs Vitest suites
clarinet test     # Optional: run Clarinet-native tests
```

When preparing a testnet release:

1. Sync the latest audited simnet contracts into `beta/contracts`.
2. Update `Clarinet.toml` inside `beta/` with the appropriate principals.
3. Run `clarinet check` / `clarinet deploy` against your target environment.

---

## Security Notes

- **Access Control**: All state-changing calls check either `tx-sender` or `contract-caller` against admin lists, audited registries, or pot ownership.
- **Funds Safety**: Principal refunds use memoized STX transfers for traceability, and rewards are split only after verifying sufficient sBTC balances.
- **Timing Guards**: Join/claim/delegate functions validate burn block heights against PoX cycles to prevent premature or late actions.
- **Event Logging**: Every critical action (`register-pot`, `delegate-to-pot`, `dispatch-rewards`, etc.) emits structured prints to simplify off-chain monitoring.

---

## License & Contributions

Licensed under ISC. Pull requests are welcome—run both Clarinet and Vitest test suites before submitting, and keep README updates aligned with the simnet contract sources.
