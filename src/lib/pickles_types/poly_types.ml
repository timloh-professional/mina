(** Handy module types that can be used to shorten signatures *)

(** A module type that only has a single type t with no parameters *)
module type T0 = sig
  type t
end

(** A module type that only has a single type t with 1 parameter *)
module type T1 = sig
  type _ t
end

(** A module type that only has a single type t with 2 parameters *)
module type T2 = sig
  type (_, _) t
end

(** A module type that only has a single type t with 3 parameters *)
module type T3 = sig
  type (_, _, _) t
end

(** A module type that only has a single type t with 4 parameters *)
module type T4 = sig
  type (_, _, _, _) t
end

(** A module type that only has a single type t with 5 parameters *)
module type T5 = sig
  type (_, _, _, _, _) t
end
