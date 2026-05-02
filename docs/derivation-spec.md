# Haven-AOL Derivation Spec v1

**Haven-AOL** (*Always Online* on DFINITY ICP) specifies derivation inputs for conditional, token-gated VetKD keys — supporting smart access patterns across web3 (DAOs, DataDAOs, agent swarms, shared resources).

> **Status:** Authoritative — all implementations (Motoko, Python, TypeScript) MUST produce byte-identical output for the same inputs.

**Wire identifiers:** Protocol v1 retains the historical domain tag `"accessol"` and VetKD context `"accessol_v1"` so existing ciphertexts and gates remain compatible.

---

## 1. Hash Function

**SHA-256** (FIPS 180-4).

Rationale: Available natively in all three target environments — Motoko (`mo:core` via `Sha256`), Python (`hashlib.sha256`), TypeScript/browser (`crypto.subtle.digest("SHA-256", ...)`). Produces 32 bytes, matching the VetKD `input` parameter size.

---

## 2. Field Serialization

Each of the four gate parameters is serialized to UTF-8 bytes as follows:

| Field | Type | Serialization | Example |
|---|---|---|---|
| `chain` | string | UTF-8 encoding of the Candid `Chain` variant name exactly as written | `"EthMainnet"` → `[69,116,104,77,97,105,110,110,101,116]` |
| `tokenAddress` | string | UTF-8 encoding of the `0x`-prefixed checksummed hex address, preserving original case | `"0xA0b8..."` → UTF-8 bytes of that string |
| `threshold` | non-negative integer | UTF-8 encoding of the **base-10 decimal string** representation, no leading zeros (except `"0"` itself), no sign prefix | `1000000` → `"1000000"` → `[49,48,48,48,48,48,48]` |
| `cid` | string | UTF-8 encoding of the IPFS CID string as-is | `"QmXoy..."` → UTF-8 bytes of that string |

### Threshold Encoding Rules

- The threshold is an arbitrary-precision non-negative integer.
- Serialize as its canonical base-10 decimal string: no leading zeros, no `+` sign, no underscores, no scientific notation.
- `0` serializes as `"0"` (single character).
- `1000000000000000000` (1e18) serializes as `"1000000000000000000"` (19 characters).

### Chain Variant Names (Exhaustive for v1)

These strings are the **only** valid `chain` values. They match the Candid `Chain` variant names and the EVM RPC canister's supported chains:

- `EthMainnet`
- `EthSepolia`
- `ArbitrumOne`
- `BaseMainnet`
- `OptimismMainnet`

---

## 3. Concatenation Scheme

Fields are concatenated with a **colon** (`:`, U+003A, byte `0x3A`) separator, prefixed by a fixed domain tag:

```
"accessol" ":" chain ":" tokenAddress ":" threshold ":" cid
```

The domain tag `"accessol"` prevents collisions with other applications that might hash similar tuples.

### Formal Definition

```
preimage = UTF-8("accessol") || 0x3A
        || UTF-8(chain)      || 0x3A
        || UTF-8(tokenAddress)|| 0x3A
        || UTF-8(threshold)   || 0x3A
        || UTF-8(cid)
```

Where `||` denotes byte concatenation and `0x3A` is the colon byte.

### Properties

- **Deterministic:** Same inputs always produce the same preimage.
- **Unambiguous:** Because `:` cannot appear in any field value (chain names have no colons, Ethereum addresses are hex, thresholds are decimal digits, CIDs are base32/base58), the concatenation is injection-free — no two distinct input tuples produce the same preimage.
- **Simple:** Implementable in one line in any language — no length-prefixing, no CBOR, no protobuf.

---

## 4. Output

```
derivation_input = SHA-256(preimage)
```

The output is **32 raw bytes** (not hex-encoded). This value is used as:
- The `input` parameter in `vetkd_derive_key`
- The IBE identity in `IbeCiphertext.encrypt` / `IbeIdentity.fromBytes`

---

## 5. VetKD Configuration

These values are fixed for Haven-AOL protocol v1 and MUST be used consistently across all components:

| Parameter | Value |
|---|---|
| `context` | `"accessol_v1"` (UTF-8 bytes: `[97,99,99,101,115,115,111,108,95,118,49]`) |
| `key_id.curve` | `bls12_381_g2` |
| `key_id.name` (v1 mainnet) | `"insecure_test_key_1"` (via chain-key testing canister `vrqyr-saaaa-aaaan-qzn4q-cai`) |
| `key_id.name` (local dev) | `"test_key_1"` (via management canister `aaaaa-aa`) |

---

## 6. Test Vectors

### Test Vector 1 — Ethereum Mainnet, USDC, 1M units

| Field | Value |
|---|---|
| `chain` | `EthMainnet` |
| `tokenAddress` | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| `threshold` | `1000000` |
| `cid` | `QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco` |

**Preimage (UTF-8 string):**
```
accessol:EthMainnet:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48:1000000:QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco
```

**Expected SHA-256 (hex):**
```
e16d8738a6ea707f75e887fd3fce3e96d2fe061d075c5fe2821e94b2c9ad3b17
```

### Test Vector 2 — Arbitrum One, USDC.e, 0.5 ETH-scale threshold

| Field | Value |
|---|---|
| `chain` | `ArbitrumOne` |
| `tokenAddress` | `0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8` |
| `threshold` | `500000000000000000` |
| `cid` | `bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi` |

**Preimage (UTF-8 string):**
```
accessol:ArbitrumOne:0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8:500000000000000000:bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi
```

**Expected SHA-256 (hex):**
```
04308f0e299c1647072257d0965e1f982fba21030538ee89323f82cab1c995d3
```

### Test Vector 3 — Edge case: Sepolia, threshold = 0

| Field | Value |
|---|---|
| `chain` | `EthSepolia` |
| `tokenAddress` | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |
| `threshold` | `0` |
| `cid` | `QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn` |

**Preimage (UTF-8 string):**
```
accessol:EthSepolia:0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238:0:QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn
```

**Expected SHA-256 (hex):**
```
6ea156594a7f7400610f328f4b5daf61d3036100d7bab69d33eb2a53575936d7
```

---

## 7. Pseudocode

```
function computeDerivationInput(chain, tokenAddress, threshold, cid):
    preimage = "accessol:" + chain + ":" + tokenAddress + ":" + str(threshold) + ":" + cid
    return SHA256(UTF8_ENCODE(preimage))
```

---

## 8. Gate Metadata JSON Schema

The gate metadata is a JSON object produced by the upload-side (Python package) and consumed by the decrypt-side (TypeScript package). It is **not** stored on ICP — it travels out-of-band (URL, QR code, chat message, NFT attribute, etc.).

### Schema

```json
{
  "version": 1,
  "cid": "<IPFS CID string>",
  "chain": "<Chain variant name>",
  "tokenAddress": "<0x-prefixed checksummed address>",
  "threshold": "<base-10 integer string>",
  "encryptedAesKey": "<base64-encoded serialized IbeCiphertext>"
}
```

### Field Definitions

| Field | Type | Required | Description |
|---|---|---|---|
| `version` | integer | yes | Schema version. Always `1` for v1. Future versions may add fields. |
| `cid` | string | yes | IPFS CID of the encrypted file blob. Used to fetch the ciphertext and as an input to the derivation hash. |
| `chain` | string | yes | Must exactly match one of the `Chain` variant names: `EthMainnet`, `EthSepolia`, `ArbitrumOne`, `BaseMainnet`, `OptimismMainnet`. |
| `tokenAddress` | string | yes | ERC-20 contract address. `0x`-prefixed, checksummed hex (EIP-55). 42 characters. |
| `threshold` | string | yes | Minimum token balance required, in the token's smallest unit (e.g., wei for ETH, 1e6 units for USDC). Encoded as a **base-10 integer string** to avoid JSON number precision loss for values > 2^53. No leading zeros. |
| `encryptedAesKey` | string | yes | The AES-256 key, IBE-encrypted to the derivation identity, then serialized and **standard base64-encoded** (RFC 4648 §4, with `+/` alphabet and `=` padding). |

### Validation Rules

- `version` must equal `1`.
- `chain` must be one of the five enumerated variant names.
- `tokenAddress` must match `/^0x[0-9a-fA-F]{40}$/`.
- `threshold` must match `/^(0|[1-9][0-9]*)$/` (non-negative integer, no leading zeros).
- `encryptedAesKey` must be valid standard base64.
- `cid` must be a non-empty string.

### Base64 Encoding

`encryptedAesKey` uses **standard base64** (RFC 4648 §4):
- Alphabet: `A-Z`, `a-z`, `0-9`, `+`, `/`
- Padding: `=` (required)
- Not URL-safe base64 (no `-_`)

Rationale: Standard base64 is the default in Python (`base64.b64encode`), TypeScript (`btoa` / `Buffer.from(...).toString('base64')`), and most libraries. URL-safe encoding would require explicit opt-in in most environments.
