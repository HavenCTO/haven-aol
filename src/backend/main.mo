import Nat "mo:core/Nat";
import Nat8 "mo:core/Nat8";
import Text "mo:core/Text";
import Char "mo:core/Char";
import Blob "mo:core/Blob";
import Error "mo:core/Error";
import Result "mo:core/Result";
import Runtime "mo:core/Runtime";
import Sha256 "mo:sha2/Sha256";

// Haven-AOL (Always Online on DFINITY ICP): smart access management with conditional keys
// for web3 — DAOs, DataDAOs, agent swarms, and shared gated resources.
persistent actor {

  // ── EVM RPC canister types (from evm_rpc.did) ──────────────────────

  type RpcServices = {
    #EthMainnet : ?[EthMainnetService];
    #EthSepolia : ?[EthSepoliaService];
    #ArbitrumOne : ?[L2MainnetService];
    #BaseMainnet : ?[L2MainnetService];
    #OptimismMainnet : ?[L2MainnetService];
  };

  type EthMainnetService = {
    #Alchemy; #Ankr; #BlockPi; #Cloudflare; #PublicNode; #Llama;
  };

  type EthSepoliaService = {
    #Alchemy; #Ankr; #BlockPi; #PublicNode; #Sepolia;
  };

  type L2MainnetService = {
    #Alchemy; #Ankr; #BlockPi; #PublicNode; #Llama;
  };

  type ConsensusStrategy = {
    #Equality;
    #Threshold : { total : ?Nat8; min : Nat8 };
  };

  type RpcConfig = {
    responseSizeEstimate : ?Nat64;
    responseConsensus : ?ConsensusStrategy;
  };

  type TransactionRequest = {
    to : ?Text;
    input : ?Text;
    accessList : ?[{ address : Text; storageKeys : [Text] }];
    blobVersionedHashes : ?[Text];
    blobs : ?[Text];
    chainId : ?Nat;
    from : ?Text;
    gas : ?Nat;
    gasPrice : ?Nat;
    maxFeePerBlobGas : ?Nat;
    maxFeePerGas : ?Nat;
    maxPriorityFeePerGas : ?Nat;
    nonce : ?Nat;
    type_ : ?Text;
    value : ?Nat;
  };

  type BlockTag = {
    #Earliest; #Safe; #Finalized; #Latest; #Number : Nat; #Pending;
  };

  type CallArgs = {
    transaction : TransactionRequest;
    block : ?BlockTag;
  };

  type RejectionCode = {
    #NoError; #CanisterError; #SysTransient;
    #DestinationInvalid; #Unknown; #SysFatal; #CanisterReject;
  };

  type HttpOutcallError = {
    #IcError : { code : RejectionCode; message : Text };
    #InvalidHttpJsonRpcResponse : { status : Nat16; body : Text; parsingError : ?Text };
  };

  type JsonRpcError = { code : Int64; message : Text };

  type ValidationError = {
    #CredentialPathNotAllowed;
    #HostNotAllowed : Text;
    #CredentialHeaderNotAllowed;
    #UrlParseError : Text;
    #Custom : Text;
  };

  type ProviderError = {
    #TooFewCycles : { expected : Nat; received : Nat };
    #MissingRequiredProvider;
    #ProviderNotFound;
    #NoPermission;
    #InvalidRpcConfig : Text;
  };

  type RpcError = {
    #JsonRpcError : JsonRpcError;
    #ProviderError : ProviderError;
    #ValidationError : ValidationError;
    #HttpOutcallError : HttpOutcallError;
  };

  type CallResult = {
    #Ok : Text;
    #Err : RpcError;
  };

  type RpcService = {
    #Provider : Nat64;
    #Custom : { url : Text; headers : ?[{ name : Text; value : Text }] };
    #EthSepolia : EthSepoliaService;
    #EthMainnet : EthMainnetService;
    #ArbitrumOne : L2MainnetService;
    #BaseMainnet : L2MainnetService;
    #OptimismMainnet : L2MainnetService;
  };

  type MultiCallResult = {
    #Consistent : CallResult;
    #Inconsistent : [(RpcService, CallResult)];
  };

  type EvmRpcCanister = actor {
    eth_call : (RpcServices, ?RpcConfig, CallArgs) -> async MultiCallResult;
  };

  // ── VetKD types ────────────────────────────────────────────────────

  type VetKdCurve = { #bls12_381_g2 };

  type VetKdKeyId = {
    curve : VetKdCurve;
    name : Text;
  };

  type VetKdPublicKeyRequest = {
    canister_id : ?Principal;
    context : Blob;
    key_id : VetKdKeyId;
  };

  type VetKdPublicKeyResponse = {
    public_key : Blob;
  };

  type VetKdDeriveKeyRequest = {
    input : Blob;
    context : Blob;
    transport_public_key : Blob;
    key_id : VetKdKeyId;
  };

  type VetKdDeriveKeyResponse = {
    encrypted_key : Blob;
  };

  type VetKdCanister = actor {
    vetkd_public_key : (VetKdPublicKeyRequest) -> async VetKdPublicKeyResponse;
    vetkd_derive_key : (VetKdDeriveKeyRequest) -> async VetKdDeriveKeyResponse;
  };

  // ── Public types ───────────────────────────────────────────────────

  public type Chain = {
    #EthMainnet;
    #EthSepolia;
    #ArbitrumOne;
    #BaseMainnet;
    #OptimismMainnet;
  };

  public type BalanceError = {
    #InvalidAddress : Text;
    #EvmRpcError : Text;
  };

  // ── Constants ──────────────────────────────────────────────────────

  let CYCLE_BUDGET : Nat = 10_000_000_000;
  // VetKD context — protocol v1 identifier (stable across Haven-AOL deployments).
  let VETKD_CONTEXT : Blob = Text.encodeUtf8("accessol_v1");

  // ── EVM RPC canister reference ─────────────────────────────────────

  transient let evmRpc : EvmRpcCanister = do {
    let ?id = Runtime.envVar("PUBLIC_CANISTER_ID:evm_rpc")
      else Runtime.trap("PUBLIC_CANISTER_ID:evm_rpc not set");
    actor (id) : EvmRpcCanister;
  };

  // ── VetKD canister reference ───────────────────────────────────────
  // Local dev: management canister "aaaaa-aa" with "test_key_1"
  // Mainnet v1: chain-key testing canister with "insecure_test_key_1"

  transient let vetkdCanister : VetKdCanister = do {
    let id = switch (Runtime.envVar("VETKD_CANISTER_ID")) {
      case (?v) { v };
      case null { "aaaaa-aa" }; // default: management canister (local dev)
    };
    actor (id) : VetKdCanister;
  };

  transient let vetkdKeyName : Text = do {
    switch (Runtime.envVar("VETKD_KEY_NAME")) {
      case (?v) { v };
      case null { "key_1" }; // default: local dev key (auto-provisioned by replica)
    };
  };

  func vetkdKeyId() : VetKdKeyId {
    { curve = #bls12_381_g2; name = vetkdKeyName };
  };

  // ── Chain mapping ──────────────────────────────────────────────────

  func chainToRpcServices(chain : Chain) : RpcServices {
    switch (chain) {
      case (#EthMainnet) { #EthMainnet(null) };
      case (#EthSepolia) { #EthSepolia(null) };
      case (#ArbitrumOne) { #ArbitrumOne(null) };
      case (#BaseMainnet) { #BaseMainnet(null) };
      case (#OptimismMainnet) { #OptimismMainnet(null) };
    };
  };

  func chainToText(chain : Chain) : Text {
    switch (chain) {
      case (#EthMainnet) { "EthMainnet" };
      case (#EthSepolia) { "EthSepolia" };
      case (#ArbitrumOne) { "ArbitrumOne" };
      case (#BaseMainnet) { "BaseMainnet" };
      case (#OptimismMainnet) { "OptimismMainnet" };
    };
  };

  // ── Hex utilities ──────────────────────────────────────────────────

  func isHexChar(c : Char) : Bool {
    (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
  };

  func hexCharToNat(c : Char) : Nat {
    let code = Char.toNat32(c);
    if (c >= '0' and c <= '9') { Nat.fromNat32(code - 48) }
    else if (c >= 'a' and c <= 'f') { Nat.fromNat32(code - 87) }
    else { Nat.fromNat32(code - 55) };
  };

  func stripHexPrefix(hex : Text) : Text {
    let chars = hex.chars();
    switch (chars.next(), chars.next()) {
      case (?'0', ?'x') {
        var rest = "";
        for (c in chars) { rest #= Text.fromChar(c) };
        rest;
      };
      case (?'0', ?'X') {
        var rest = "";
        for (c in chars) { rest #= Text.fromChar(c) };
        rest;
      };
      case _ { hex };
    };
  };

  func hexToNat(hex : Text) : ?Nat {
    let stripped = stripHexPrefix(hex);
    if (stripped.size() == 0) return ?0;
    var result : Nat = 0;
    for (c in stripped.chars()) {
      if (not isHexChar(c)) return null;
      result := result * 16 + hexCharToNat(c);
    };
    ?result;
  };

  func toLowerHex(hex : Text) : Text {
    var out = "";
    for (c in hex.chars()) {
      out #= Text.fromChar(if (c >= 'A' and c <= 'F') {
        Char.fromNat32(Char.toNat32(c) + 32)
      } else { c });
    };
    out;
  };

  // ── Address validation ─────────────────────────────────────────────

  func validateEvmAddress(addr : Text) : Result.Result<Text, Text> {
    if (addr.size() != 42) return #err("address must be 42 characters (0x + 40 hex)");
    let stripped = stripHexPrefix(addr);
    if (stripped.size() != 40) return #err("address must start with 0x");
    for (c in stripped.chars()) {
      if (not isHexChar(c)) return #err("address contains non-hex character");
    };
    #ok(toLowerHex(stripped));
  };

  // ── Derivation input hash ──────────────────────────────────────────
  // Per docs/derivation-spec.md:
  //   preimage = "accessol:" + chain + ":" + tokenAddress + ":" + str(threshold) + ":" + cid
  //   derivation_input = SHA-256(UTF-8(preimage))

  func computeDerivationInput(
    chain : Chain,
    tokenAddress : Text,
    threshold : Nat,
    cid : Text,
  ) : Blob {
    let preimage = "accessol:" # chainToText(chain) # ":" # tokenAddress # ":" # Nat.toText(threshold) # ":" # cid;
    Sha256.fromBlob(#sha256, Text.encodeUtf8(preimage));
  };

  // ── VetKD key derivation ───────────────────────────────────────────

  func deriveKey(
    derivationInput : Blob,
    transportPublicKey : Blob,
  ) : async Blob {
    let response = await (with cycles = CYCLE_BUDGET) vetkdCanister.vetkd_derive_key({
      input = derivationInput;
      context = VETKD_CONTEXT;
      transport_public_key = transportPublicKey;
      key_id = vetkdKeyId();
    });
    response.encrypted_key;
  };

  // ── Public endpoints ───────────────────────────────────────────────

  /// Returns the canister's VetKD verification public key.
  /// This is an update call (not query) because it makes an inter-canister call.
  public func getVetKDPublicKey() : async Blob {
    let response = await vetkdCanister.vetkd_public_key({
      canister_id = null;
      context = VETKD_CONTEXT;
      key_id = vetkdKeyId();
    });
    response.public_key;
  };

  // ── Balance check ──────────────────────────────────────────────────

  public func checkBalance(
    chain : Chain,
    tokenAddress : Text,
    evmAddress : Text,
  ) : async Result.Result<Nat, BalanceError> {

    switch (validateEvmAddress(tokenAddress)) {
      case (#err(msg)) { return #err(#InvalidAddress("tokenAddress: " # msg)) };
      case (#ok(_)) {};
    };

    let walletHex = switch (validateEvmAddress(evmAddress)) {
      case (#err(msg)) { return #err(#InvalidAddress("evmAddress: " # msg)) };
      case (#ok(h)) { h };
    };

    let calldata = "0x70a08231000000000000000000000000" # walletHex;

    let rpcConfig : RpcConfig = {
      responseSizeEstimate = null;
      responseConsensus = ?#Threshold({ total = ?3 : ?Nat8; min = 2 : Nat8 });
    };

    let callArgs : CallArgs = {
      transaction = {
        to = ?tokenAddress;
        input = ?calldata;
        accessList = null;
        blobVersionedHashes = null;
        blobs = null;
        chainId = null;
        from = null;
        gas = null;
        gasPrice = null;
        maxFeePerBlobGas = null;
        maxFeePerGas = null;
        maxPriorityFeePerGas = null;
        nonce = null;
        type_ = null;
        value = null;
      };
      block = null;
    };

    let result = await (with cycles = CYCLE_BUDGET) evmRpc.eth_call(
      chainToRpcServices(chain),
      ?rpcConfig,
      callArgs,
    );

    switch (result) {
      case (#Consistent(#Ok(hexBalance))) {
        switch (hexToNat(hexBalance)) {
          case (?balance) { #ok(balance) };
          case null { #err(#EvmRpcError("failed to parse hex balance: " # hexBalance)) };
        };
      };
      case (#Consistent(#Err(rpcError))) {
        #err(#EvmRpcError("RPC error: " # debug_show rpcError));
      };
      case (#Inconsistent(results)) {
        #err(#EvmRpcError("providers returned inconsistent results: " # debug_show results));
      };
    };
  };

  // ── Public types for gate endpoint ───────────────────────────────

  public type GateRequest = {
    chain : Chain;
    tokenAddress : Text;
    threshold : Nat;
    cid : Text;
    evmAddress : Text;
    transportPublicKey : Blob;
  };

  public type GateError = {
    #InsufficientBalance : { required : Nat; actual : Nat };
    #InvalidAddress : Text;
    #InvalidThreshold;
    #EvmRpcError : Text;
    #VetKDError : Text;
  };

  public type GateResult = {
    #ok : Blob;
    #err : GateError;
  };

  // ── Input validation ───────────────────────────────────────────────

  func validateAddress(addr : Text, fieldName : Text) : ?GateError {
    if (addr.size() != 42) return ?#InvalidAddress(fieldName # ": address must be 42 characters (0x + 40 hex)");
    let stripped = stripHexPrefix(addr);
    if (stripped.size() != 40) return ?#InvalidAddress(fieldName # ": address must start with 0x");
    for (c in stripped.chars()) {
      if (not isHexChar(c)) return ?#InvalidAddress(fieldName # ": address contains non-hex character");
    };
    null;
  };

  // ── requestDecryptionKey endpoint ──────────────────────────────────

  public func requestDecryptionKey(req : GateRequest) : async GateResult {
    // Input validation
    switch (validateAddress(req.tokenAddress, "tokenAddress")) {
      case (?e) { return #err(e) };
      case null {};
    };
    switch (validateAddress(req.evmAddress, "evmAddress")) {
      case (?e) { return #err(e) };
      case null {};
    };
    if (req.threshold == 0) return #err(#InvalidThreshold);
    if (req.cid.size() == 0) return #err(#InvalidAddress("cid must not be empty"));
    if (Blob.toArray(req.transportPublicKey).size() == 0) return #err(#InvalidAddress("transportPublicKey must not be empty"));

    // Step 1: EVM balance check
    let balanceResult = await checkBalance(req.chain, req.tokenAddress, req.evmAddress);
    let balance = switch (balanceResult) {
      case (#ok(b)) { b };
      case (#err(#InvalidAddress(msg))) { return #err(#InvalidAddress(msg)) };
      case (#err(#EvmRpcError(msg))) { return #err(#EvmRpcError(msg)) };
    };

    // Step 2: Threshold comparison
    if (balance < req.threshold) {
      return #err(#InsufficientBalance({ required = req.threshold; actual = balance }));
    };

    // Step 3: VetKD key derivation
    let derivationInput = computeDerivationInput(req.chain, req.tokenAddress, req.threshold, req.cid);
    try {
      let encryptedKey = await deriveKey(derivationInput, req.transportPublicKey);
      #ok(encryptedKey);
    } catch (e) {
      #err(#VetKDError(Error.message(e)));
    };
  };

  // ── Health check ───────────────────────────────────────────────────

  public query func health() : async Text { "ok" };
};
