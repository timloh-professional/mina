use ark_ff::{BigInteger as ark_BigInteger, BigInteger256};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use num_bigint::BigUint;
use std::cmp::Ordering::{Equal, Greater, Less};
use std::convert::TryInto;
use std::ops::Deref;

//
// Wrapper struct to implement OCaml bindings
//

#[derive(Clone, Copy)]
pub struct CamlBigInteger256(pub BigInteger256);

impl From<BigInteger256> for CamlBigInteger256 {
    fn from(big: BigInteger256) -> Self {
        Self(big)
    }
}

unsafe impl ocaml::FromValue for CamlBigInteger256 {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlBigInteger256 {
    extern "C" fn ocaml_compare(x: ocaml::Value, y: ocaml::Value) -> i32 {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(x);
        let y: ocaml::Pointer<Self> = ocaml::FromValue::from_value(y);
        match x.as_ref().0.cmp(&y.as_ref().0) {
            core::cmp::Ordering::Less => -1,
            core::cmp::Ordering::Equal => 0,
            core::cmp::Ordering::Greater => 1,
        }
    }
}

impl ocaml::Custom for CamlBigInteger256 {
    ocaml::custom! {
        name: "CamlBigInteger256",
        compare: CamlBigInteger256::ocaml_compare,
    }
}

impl Deref for CamlBigInteger256 {
    type Target = BigInteger256;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy constants
//

const BIGINT256_NUM_BITS: i32 = 256;
const BIGINT256_LIMB_BITS: i32 = 64;
const BIGINT256_LIMB_BYTES: i32 = BIGINT256_LIMB_BITS / 8;
const BIGINT256_NUM_LIMBS: i32 =
    (BIGINT256_NUM_BITS + BIGINT256_LIMB_BITS - 1) / BIGINT256_LIMB_BITS;

//
// BigUint handy methods
//

impl CamlBigInteger256 {
    pub fn to_biguint(&self) -> BigUint {
        let bytes = self.to_bytes_le();
        num_bigint::BigUint::from_bytes_le(&bytes)
    }

    /// This converts a [BigUint] into a [CamlBigInteger256].
    /// The function can panic if `x` is larger than [CamlBigInteger256].
    pub fn of_biguint(x: &BigUint) -> Self {
        let mut result = [0u64; BIGINT256_NUM_LIMBS as usize];
        let serialized = x.to_u64_digits();
        assert!(serialized.len() <= BIGINT256_NUM_LIMBS as usize);
        result.copy_from_slice(&serialized);
        Self(BigInteger256(result))
    }
}

//
// OCaml stuff
//

#[ocaml::func]
pub fn caml_bigint_256_of_numeral(
    s: &[u8],
    _len: u32,
    base: u32,
) -> Result<CamlBigInteger256, ocaml::Error> {
    match BigUint::parse_bytes(s, base) {
        Some(data) => Ok(CamlBigInteger256::of_biguint(&data)),
        None => Err(ocaml::Error::invalid_argument("caml_bigint_256_of_numeral")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_of_decimal_string(s: &[u8]) -> Result<CamlBigInteger256, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlBigInteger256::of_biguint(&data)),
        None => Err(
            ocaml::Error::invalid_argument("caml_bigint_256_of_decimal_string")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_num_limbs() -> ocaml::Int {
    return BIGINT256_NUM_LIMBS.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_256_bytes_per_limb() -> ocaml::Int {
    return BIGINT256_LIMB_BYTES.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_256_div(
    x: ocaml::Pointer<CamlBigInteger256>,
    y: ocaml::Pointer<CamlBigInteger256>,
) -> CamlBigInteger256 {
    let res: BigUint = x.as_ref().to_biguint() / y.as_ref().to_biguint();
    CamlBigInteger256::of_biguint(&res)
}

#[ocaml::func]
pub fn caml_bigint_256_compare(
    x: ocaml::Pointer<CamlBigInteger256>,
    y: ocaml::Pointer<CamlBigInteger256>,
) -> ocaml::Int {
    match x.as_ref().cmp(y.as_ref()) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_bigint_256_print(x: ocaml::Pointer<CamlBigInteger256>) {
    println!("{}", x.as_ref().to_biguint());
}

#[ocaml::func]
pub fn caml_bigint_256_to_string(x: ocaml::Pointer<CamlBigInteger256>) -> String {
    x.as_ref().to_biguint().to_string()
}

#[ocaml::func]
pub fn caml_bigint_256_test_bit(
    x: ocaml::Pointer<CamlBigInteger256>,
    i: ocaml::Int,
) -> Result<bool, ocaml::Error> {
    match i.try_into() {
        Ok(i) => Ok(x.as_ref().get_bit(i)),
        Err(_) => Err(ocaml::Error::invalid_argument("caml_bigint_256_test_bit")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_to_bytes(x: ocaml::Pointer<CamlBigInteger256>) -> ocaml::Value {
    let len = std::mem::size_of::<CamlBigInteger256>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    let x_ptr: *const CamlBigInteger256 = x.as_ref();
    unsafe {
        let mut input_bytes = vec![];
        (*x_ptr)
            .0
            .serialize(&mut input_bytes)
            .expect("serialize failed");
        core::ptr::copy_nonoverlapping(
            input_bytes.as_ptr(),
            ocaml::sys::string_val(str),
            input_bytes.len(),
        );
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_bigint_256_of_bytes(x: &[u8]) -> Result<CamlBigInteger256, ocaml::Error> {
    let len = std::mem::size_of::<CamlBigInteger256>();
    if x.len() != len {
        ocaml::Error::failwith("caml_bigint_256_of_bytes")?;
    };
    let result = BigInteger256::deserialize(&mut &x[..])
        .map_err(|_| ocaml::Error::Message("deserialization error"))?;
    Ok(CamlBigInteger256(result))
}

#[ocaml::func]
pub fn caml_bigint_256_deep_copy(x: CamlBigInteger256) -> CamlBigInteger256 {
    x
}
