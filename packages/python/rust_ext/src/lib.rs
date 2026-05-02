use ic_vetkeys::{DerivedPublicKey, IbeCiphertext, IbeIdentity, IbeSeed, MasterPublicKey};
use ic_cdk::management_canister::{VetKDCurve, VetKDKeyId};
use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;

/// Derive the VetKD verification key offline from the mainnet master public key.
#[pyfunction]
fn derive_verification_key(
    key_name: &str,
    canister_id_bytes: &[u8],
    context: &[u8],
) -> PyResult<Vec<u8>> {
    let key_id = VetKDKeyId {
        curve: VetKDCurve::Bls12_381_G2,
        name: key_name.to_string(),
    };
    let master_key = MasterPublicKey::for_mainnet_key(&key_id)
        .ok_or_else(|| PyValueError::new_err(format!("Unknown key name: {key_name}")))?;
    let canister_key = master_key.derive_canister_key(canister_id_bytes);
    let derived_key = canister_key.derive_sub_key(context);
    Ok(derived_key.serialize())
}

/// Deserialize a DerivedPublicKey from bytes (e.g. fetched from canister).
#[pyfunction]
fn deserialize_derived_public_key(bytes: &[u8]) -> PyResult<Vec<u8>> {
    let dpk = DerivedPublicKey::deserialize(bytes)
        .map_err(|_| PyValueError::new_err("Invalid DerivedPublicKey bytes"))?;
    Ok(dpk.serialize())
}

/// IBE-encrypt plaintext using a derived public key and identity.
#[pyfunction]
fn ibe_encrypt(
    derived_public_key_bytes: &[u8],
    identity_bytes: &[u8],
    plaintext: &[u8],
) -> PyResult<Vec<u8>> {
    let derived_key = DerivedPublicKey::deserialize(derived_public_key_bytes)
        .map_err(|_| PyValueError::new_err("Invalid DerivedPublicKey bytes"))?;
    let identity = IbeIdentity::from_bytes(identity_bytes);
    let seed = IbeSeed::random(&mut rand::thread_rng());
    let ciphertext = IbeCiphertext::encrypt(&derived_key, &identity, plaintext, &seed);
    Ok(ciphertext.serialize())
}

#[pymodule]
fn haven_aol_vetkeys(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(derive_verification_key, m)?)?;
    m.add_function(wrap_pyfunction!(deserialize_derived_public_key, m)?)?;
    m.add_function(wrap_pyfunction!(ibe_encrypt, m)?)?;
    Ok(())
}
