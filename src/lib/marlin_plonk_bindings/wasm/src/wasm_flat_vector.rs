use wasm_bindgen::convert::{OptionIntoWasmAbi, IntoWasmAbi, OptionFromWasmAbi, FromWasmAbi};

use std::ops::Deref;
use std::convert::{From};

pub struct WasmFlatVector<T>(Vec<T>);

pub trait FlatVectorElem {
    const FLATTENED_SIZE: usize;
    fn flatten(self) -> Vec<u8>;
    fn unflatten(flat: Vec<u8>) -> Self;
}

impl<T> Deref for WasmFlatVector<T> {
    type Target = Vec<T>;

    fn deref(&self) -> &Self::Target { &self.0 }
}

impl<T> From<Vec<T>> for WasmFlatVector<T> {
    fn from(x: Vec<T>) -> Self {
        WasmFlatVector(x)
    }
}

impl<T> From<WasmFlatVector<T>> for Vec<T> {
    fn from(x: WasmFlatVector<T>) -> Self {
        x.0
    }
}

impl<'a, T> From<&'a WasmFlatVector<T>> for &'a Vec<T> {
    fn from(x: &'a WasmFlatVector<T>) -> Self {
        &x.0
    }
}

impl<T> wasm_bindgen::describe::WasmDescribe for WasmFlatVector<T> {
    fn describe() { <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe() }
}

impl<T: FlatVectorElem> FromWasmAbi for WasmFlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let data: Vec<u8> = FromWasmAbi::from_abi(js);
        let mut res: Vec<T> = Vec::with_capacity(data.len() / T::FLATTENED_SIZE);

        let mut buf = Vec::with_capacity(T::FLATTENED_SIZE);
        let mut count = 0;
        for x in data.into_iter() {
            assert!(buf.len() < T::FLATTENED_SIZE);
            buf.push(x);
            if (buf.len() >= T::FLATTENED_SIZE) {
                res.push(T::unflatten(buf));
                buf = Vec::with_capacity(T::FLATTENED_SIZE);
            }
        }
        assert_eq!(buf.len(), 0);
        WasmFlatVector(res)
    }
}

impl<T: FlatVectorElem> OptionFromWasmAbi for WasmFlatVector<T> {
    fn is_none(x: &Self::Abi) -> bool {
        <Vec<u8> as OptionFromWasmAbi>::is_none(x)
    }
}

impl<T: FlatVectorElem> IntoWasmAbi for WasmFlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let mut data: Vec<u8> = Vec::with_capacity(self.0.len() * T::FLATTENED_SIZE);
        for x in self.0.into_iter() {
            data.extend(x.flatten().into_iter());
        }
        IntoWasmAbi::into_abi(data)
    }
}

impl<T: FlatVectorElem> OptionIntoWasmAbi for WasmFlatVector<T> {
    fn none() -> Self::Abi {
        <Vec<u8> as OptionIntoWasmAbi>::none()
    }
}
