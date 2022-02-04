(** This module implements a random oracle instantiation. *)

open Core_kernel
open Backend
open Pickles_types
open Import

(** [ro lab length f] Returns a function that will determinstically return the same series of random strings of length [length], 
    based on the string [lab] and a final function [f] applied on a digest 
*)
let ro lab length f =
  let r = ref 0 in
  fun () ->
    incr r ;
    (* hashes "{lab}_{r}" with blake2s, returns digest of length  *)
    f (Common.bits_random_oracle ~length (sprintf "%s_%d" lab !r))

(** Returns the same series of random Tock fields *)
let tock = ro "fq" Tock.Field.size_in_bits Tock.Field.of_bits

(** Returns the same series of random Tick fields *)
let tick = ro "fp" Tick.Field.size_in_bits Tick.Field.of_bits

(** Returns the same series of random challenges *)
let chal = ro "chal" Challenge.Constant.length Challenge.Constant.of_bits

(** Returns random scalar challenges. 
    Note that re-executing a series of [scalar_chal] call might lead to some outputs being ignored if [chal] is called in between them. 
*)
let scalar_chal () = Scalar_challenge.create (chal ())
