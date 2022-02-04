(** A domain in PLONK is chosen to be a power of 2.
    This is because FFT is more efficient with a power of 2,
    as it keeps halving the problem (akin to bulletproof).

    Note that the pasta curves were chosen to have nice multiplicative groups,
    which carry large-power-of-2 subgroups.
    (see https://o1-labs.github.io/mina-book/crypto/plonk/domain.html)
*)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    (** Encodes *)
    type t = Pow_2_roots_of_unity of int
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

include Hashable.Make (Stable.Latest)

(** Returns the exact log2 of the domain. In other words, the domain size can be written as 2^k for k the return value of this function. *)
let log2_size (Pow_2_roots_of_unity k) = k

(** Returns the size of the domain. *)
let size t = 1 lsl log2_size t
