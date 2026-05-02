# Haven-AOL Integration Tests

## Test Cases

| ID | Name | Requires Replica | Requires IPFS |
|----|------|-----------------|---------------|
| TC-1 | Derivation hash parity (Python + TypeScript) | No | No |
| TC-2 | Full round-trip (encrypt → gate → decrypt) | Yes | Yes |
| TC-3 | Insufficient balance error | Yes | No |
| TC-4 | Input validation errors | Yes | No |
| TC-5 | IBE cross-language compatibility | No | No |
| TC-6 | AES cross-language compatibility | No | No |
| TC-7 | Multi-chain derivation hash divergence | No | No |

## Running Tests

### Offline tests only (TC-1, TC-5, TC-6, TC-7)

Install native VetKD bindings and the Python SDK from the repo root first:

```bash
pip install maturin
pip install -e packages/python/rust_ext
pip install -e "packages/python[dev]"
```

Then:

```bash
cd tests
./run-tests.sh --offline
```

### All tests (requires local replica)

```bash
# Prerequisites
pip install maturin
pip install -e packages/python/rust_ext
pip install -e "packages/python[dev]"
icp network start -d
icp deploy -e local
cd packages/typescript && npm install && npm run build && cd ../..

# Run
cd tests
./run-tests.sh

# Cleanup
icp network stop
```

## Balance Simulation Approach

**Local replica limitation:** The local EVM RPC canister has no real chain data. The `eth_call` to `balanceOf` will either fail or return zero.

**Approach used:** For TC-3 (insufficient balance) and TC-4 (input validation), we test against the local replica. The EVM RPC call is expected to either:
- Return 0 balance (triggering `InsufficientBalance`) — this validates the error path
- Return an RPC error — which we also handle as a valid negative test

For TC-2 (full round-trip), a complete end-to-end test requires either:
1. Deploying to mainnet with a known funded address, OR
2. A mock EVM RPC canister that returns a controlled balance

The test documents what would be needed and runs the portions that can be validated locally (encrypt → metadata → parse → derivation parity). The VetKD + IBE round-trip is validated in TC-5 using offline key derivation.
