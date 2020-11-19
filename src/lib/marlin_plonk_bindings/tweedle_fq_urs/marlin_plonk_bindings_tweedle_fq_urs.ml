type t

module Poly_comm = struct
  type t =
    Marlin_plonk_bindings_tweedle_dum.Affine.t
    Marlin_plonk_bindings_types.Poly_comm.t
end

external create : int -> t = "caml_tweedle_fq_urs_create"

external write : t -> string -> unit = "caml_tweedle_fq_urs_write"

external read : ?offset:int -> string -> t option = "caml_tweedle_fq_urs_read"

external lagrange_commitment :
  t -> domain_size:int -> int -> Poly_comm.t
  = "caml_tweedle_fq_urs_lagrange_commitment"

external commit_evaluations :
     t
  -> domain_size:int
  -> Marlin_plonk_bindings_tweedle_fq.t array
  -> Poly_comm.t
  = "caml_tweedle_fq_urs_commit_evaluations"

external b_poly_commitment :
  t -> Marlin_plonk_bindings_tweedle_fq.t array -> Poly_comm.t
  = "caml_tweedle_fq_urs_b_poly_commitment"

external batch_accumulator_check :
     t
  -> Marlin_plonk_bindings_tweedle_dum.Affine.t array
  -> Marlin_plonk_bindings_tweedle_fq.t array
  -> bool
  = "caml_tweedle_fq_urs_batch_accumulator_check"

external h :
  t -> Marlin_plonk_bindings_tweedle_dum.Affine.t
  = "caml_tweedle_fq_urs_h"
