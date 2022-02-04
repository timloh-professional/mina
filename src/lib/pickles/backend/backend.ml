(** The Vesta curve *)
module Tick = struct
  include Kimchi_backend.Pasta.Vesta_based_plonk

  (** Inner curve references the other curve (Pallas) *)
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end

(** The Pallas curve *)
module Tock = struct
  include Kimchi_backend.Pasta.Pallas_based_plonk

  (** Inner curve references the other curve (Vesta) *)
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Vesta
end
