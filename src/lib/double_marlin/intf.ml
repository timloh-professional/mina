open Core_kernel
module Sponge_lib = Sponge

module Snarkable = struct
  module type S1 = sig
    type _ t

    val typ :
      ('var, 'value, 'f) Snarky.Typ.t -> ('var t, 'value t, 'f) Snarky.Typ.t
  end

  module type S2 = sig
    type (_, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> (('var1, 'var2) t, ('value1, 'value2) t, 'f) Snarky.Typ.t
  end

  module type S3 = sig
    type (_, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3) t
         , ('value1, 'value2, 'value3) t
         , 'f )
         Snarky.Typ.t
  end

  module type S4 = sig
    type (_, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ('var4, 'value4, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4) t
         , ('value1, 'value2, 'value3, 'value4) t
         , 'f )
         Snarky.Typ.t
  end

  module type S5 = sig
    type (_, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ('var4, 'value4, 'f) Snarky.Typ.t
      -> ('var5, 'value5, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5) t
         , ('value1, 'value2, 'value3, 'value4, 'value5) t
         , 'f )
         Snarky.Typ.t
  end

  module type S6 = sig
    type (_, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ('var4, 'value4, 'f) Snarky.Typ.t
      -> ('var5, 'value5, 'f) Snarky.Typ.t
      -> ('var6, 'value6, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6) t
         , ('value1, 'value2, 'value3, 'value4, 'value5, 'value6) t
         , 'f )
         Snarky.Typ.t
  end

  module type S7 = sig
    type (_, _, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ('var4, 'value4, 'f) Snarky.Typ.t
      -> ('var5, 'value5, 'f) Snarky.Typ.t
      -> ('var6, 'value6, 'f) Snarky.Typ.t
      -> ('var7, 'value7, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6, 'var7) t
         , ('value1, 'value2, 'value3, 'value4, 'value5, 'value6, 'value7) t
         , 'f )
         Snarky.Typ.t
  end

  module type S8 = sig
    type (_, _, _, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky.Typ.t
      -> ('var2, 'value2, 'f) Snarky.Typ.t
      -> ('var3, 'value3, 'f) Snarky.Typ.t
      -> ('var4, 'value4, 'f) Snarky.Typ.t
      -> ('var5, 'value5, 'f) Snarky.Typ.t
      -> ('var6, 'value6, 'f) Snarky.Typ.t
      -> ('var7, 'value7, 'f) Snarky.Typ.t
      -> ('var8, 'value8, 'f) Snarky.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6, 'var7, 'var8) t
         , ( 'value1
           , 'value2
           , 'value3
           , 'value4
           , 'value5
           , 'value6
           , 'value7
           , 'value8 )
           t
         , 'f )
         Snarky.Typ.t
  end
end

module Evals = struct
  module type S = sig
    type n

    val n : n Vector.nat

    include Binable.S1 with type 'a t = ('a, n) Vector.t

    include Snarkable.S1 with type 'a t := 'a t
  end
end

module Group (Impl : Snarky.Snark_intf.Run) = struct
  open Impl

  module type S = sig
    type t

    module Constant : sig
      type t
    end

    val typ : (t, Constant.t) Typ.t

    val ( + ) : t -> t -> t

    val scale : t -> Boolean.var list -> t

    val negate : t -> t

    val to_field_elements : t -> Field.t list
  end
end

module Sponge (Impl : Snarky.Snark_intf.Run) = struct
  open Impl

  module type S =
    Sponge.Intf.Sponge
    with module Field := Field
     and module State := Sponge.State
     and type input := Field.t
     and type digest := length:int -> Boolean.var list
end

module Dlog_main_inputs = struct
  module type S = sig
    module Impl : Snarky.Snark_intf.Run with type prover_state = unit

    module Fp_params : sig
      val p : Bigint.t

      val size_in_bits : int
    end

    module G1 : Group(Impl).S

    module Generators : sig
      val g : G1.t
    end

    val domain_h : Domain.t

    val domain_k : Domain.t

    module Input_domain : sig
      val domain : Domain.t

      val lagrange_commitments : G1.t array
    end

    val sponge_params : Impl.Field.t Sponge_lib.Params.t

    module Sponge : Sponge(Impl).S
  end
end

module Pairing_main_inputs = struct
  module type S = sig
    module Impl : Snarky.Snark_intf.Run with type prover_state = unit

    module Fq_constant : sig
      type t

      val size_in_bits : int
    end

    module G : sig
      open Impl

      include Group(Impl).S

      val if_ : Boolean.var -> then_:t -> else_:t -> t

      val scale_inv : t -> Boolean.var list -> t

      val scale_by_quadratic_nonresidue : t -> t

      val scale_by_quadratic_nonresidue_inv : t -> t
    end

    module Generators : sig
      val g : G.t

      val h : G.t
    end

    val domain_h : Domain.t

    val domain_k : Domain.t

    module Input_domain : sig
      val domain : Domain.t

      val lagrange_commitments : G.t array
    end

    val sponge_params : Impl.Field.t Sponge_lib.Params.t

    module Sponge :
      Sponge_lib.Intf.Sponge
      with module Field := Impl.Field
       and module State := Sponge_lib.State
       and type input :=
                  [`Field of Impl.Field.t | `Bits of Impl.Boolean.var list]
       and type digest := length:int -> Impl.Boolean.var list

    module App_state : sig
      type t

      module Constant : sig
        type t
      end

      (* This function should be collision resistant. *)
      val to_field_elements : t -> Impl.Field.t array

      val typ : (t, Constant.t) Impl.Typ.t

      val check_update : t -> t -> unit
    end
  end
end
