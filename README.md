# Haven-AOL

**Always Online** on [DFINITY Internet Computer](https://internetcomputer.org/): an ICP-native layer for **smart access management** across web3 — **conditional key access** for token-gated content, **shared access** patterns suited to **DAOs**, **DataDAOs**, **agent swarms**, and other cooperative setups.

This repository contains:

- **Motoko canister** (`src/backend`) — balance-checked gates and VetKD-derived decryption keys.
- **TypeScript SDK** (`packages/typescript`) — decrypt-side client library (`haven-aol` on npm).
- **Python SDK** (`packages/python`) — upload-side encryption and metadata (`haven-aol` on PyPI).

Gate derivation and VetKD context strings follow **protocol v1** in [`docs/derivation-spec.md`](docs/derivation-spec.md) (wire-compatible domain tags remain `accessol` / `accessol_v1` for existing payloads).

## Quick start

See [`tests/README.md`](tests/README.md) for integration tests, local replica setup, and dependency installation (including native VetKD bindings).
