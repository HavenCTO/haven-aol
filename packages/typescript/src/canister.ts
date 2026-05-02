import { Actor, HttpAgent } from "@dfinity/agent";
import { IDL } from "@dfinity/candid";
import { Chain, GateResult } from "./types.js";

// Candid IDL factory for the Haven-AOL backend canister
const ChainVariant = IDL.Variant({
  EthMainnet: IDL.Null,
  EthSepolia: IDL.Null,
  ArbitrumOne: IDL.Null,
  BaseMainnet: IDL.Null,
  OptimismMainnet: IDL.Null,
});

const GateRequestType = IDL.Record({
  chain: ChainVariant,
  tokenAddress: IDL.Text,
  threshold: IDL.Nat,
  cid: IDL.Text,
  evmAddress: IDL.Text,
  transportPublicKey: IDL.Vec(IDL.Nat8),
});

const GateErrorVariant = IDL.Variant({
  InsufficientBalance: IDL.Record({ required: IDL.Nat, actual: IDL.Nat }),
  InvalidAddress: IDL.Text,
  InvalidThreshold: IDL.Null,
  EvmRpcError: IDL.Text,
  VetKDError: IDL.Text,
});

const GateResultVariant = IDL.Variant({
  ok: IDL.Vec(IDL.Nat8),
  err: GateErrorVariant,
});

const idlFactory = () =>
  IDL.Service({
    requestDecryptionKey: IDL.Func([GateRequestType], [GateResultVariant], []),
    getVetKDPublicKey: IDL.Func([], [IDL.Vec(IDL.Nat8)], []),
  });

function buildChainVariant(chain: Chain): Record<string, null> {
  return { [chain]: null };
}

/**
 * Call the canister's requestDecryptionKey endpoint.
 */
export async function requestDecryptionKey(
  agent: HttpAgent,
  canisterId: string,
  request: {
    chain: Chain;
    tokenAddress: string;
    threshold: bigint;
    cid: string;
    evmAddress: string;
    transportPublicKey: Uint8Array;
  },
): Promise<GateResult> {
  const actor = Actor.createActor(idlFactory, { agent, canisterId });
  const result = await actor.requestDecryptionKey({
    chain: buildChainVariant(request.chain),
    tokenAddress: request.tokenAddress,
    threshold: request.threshold,
    cid: request.cid,
    evmAddress: request.evmAddress,
    transportPublicKey: request.transportPublicKey,
  }) as GateResult;
  return result;
}

/**
 * Call the canister's getVetKDPublicKey endpoint (verification key).
 */
export async function fetchVerificationKey(
  agent: HttpAgent,
  canisterId: string,
): Promise<Uint8Array> {
  const actor = Actor.createActor(idlFactory, { agent, canisterId });
  const result = (await actor.getVetKDPublicKey()) as Uint8Array;
  return new Uint8Array(result);
}
