import { Chain, GateMetadata, VALID_CHAINS } from "./types.js";

const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
const THRESHOLD_RE = /^(0|[1-9][0-9]*)$/;

/**
 * Parse and validate gate metadata JSON.
 * Throws on invalid input.
 */
export function parseGateMetadata(json: string): GateMetadata {
  const obj = JSON.parse(json);

  if (obj.version !== 1) {
    throw new Error(`Unsupported gate metadata version: ${obj.version}`);
  }
  if (!VALID_CHAINS.includes(obj.chain)) {
    throw new Error(`Invalid chain: ${obj.chain}`);
  }
  if (typeof obj.tokenAddress !== "string" || !ADDRESS_RE.test(obj.tokenAddress)) {
    throw new Error(`Invalid tokenAddress: ${obj.tokenAddress}`);
  }
  if (typeof obj.threshold !== "string" || !THRESHOLD_RE.test(obj.threshold)) {
    throw new Error(`Invalid threshold: ${obj.threshold}`);
  }
  if (typeof obj.cid !== "string" || obj.cid.length === 0) {
    throw new Error("Missing or empty cid");
  }
  if (typeof obj.encryptedAesKey !== "string" || obj.encryptedAesKey.length === 0) {
    throw new Error("Missing or empty encryptedAesKey");
  }

  return {
    version: 1,
    cid: obj.cid,
    chain: obj.chain as Chain,
    tokenAddress: obj.tokenAddress,
    threshold: BigInt(obj.threshold),
    encryptedAesKey: obj.encryptedAesKey,
  };
}
