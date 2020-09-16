open Core_kernel
open Async_kernel

(* module Test_error = Test_error *)

(** The is a monad which is conceptually similar to `Deferred.Or_error.t`,
 *  except that there are 2 types of errors which can be returned at each bind
 *  point in a computation: soft errors, and hard errors. Soft errors do not
 *  effect the control flow of the monad, and are instead accumulated for later
 *  extraction. Hard errors effect the control flow of the monad in the same
 *  way an `Error` constructor for `Or_error.t` would.
 It remains similar to Deferred.Or_error.t in that it is a specialization of Deferred.Result.t
 *)

module Hard_fail = struct
  type t =
    { hard_error: Test_error.internal_error
    ; soft_errors: Test_error.internal_error list }
  [@@deriving eq, sexp_of, compare]
end

module Accumulator = struct
  type 'a t =
    {computation_result: 'a; soft_errors: Test_error.internal_error list}
  [@@deriving eq, sexp_of, compare]
end

type 'a t = ('a Accumulator.t, Hard_fail.t) Deferred.Result.t

module T = Monad.Make (struct
  type nonrec 'a t = 'a t

  let return a =
    Deferred.return (Ok {Accumulator.computation_result= a; soft_errors= []})

  (* 

('a, 'b) result Deferred.t ->
f:('c -> ('d, 'e) result Deferred.t) -> 
('f, 'b) result Deferred.t 

*)
  let bind res ~f =
    match%bind res with
    | Ok {Accumulator.computation_result= prev_result; soft_errors= err_list}
      -> (
        let execProg = f prev_result in
        match%bind execProg with
        | Ok {Accumulator.computation_result= comp; soft_errors= next_list} ->
            Deferred.return
              (Ok
                 { Accumulator.computation_result= comp
                 ; Accumulator.soft_errors= List.append err_list next_list })
        | Error
            {Hard_fail.hard_error= hard_err; Hard_fail.soft_errors= next_list}
          ->
            Deferred.return
              (Error
                 { Hard_fail.hard_error= hard_err
                 ; soft_errors= List.append err_list next_list }) )
    | Error _ as error ->
        Deferred.return error

  let map = `Define_using_bind
end)

include T

let return_without_deferred a =
  Ok {Accumulator.computation_result= a; soft_errors= []}

let return_unit_without_deferred =
  Ok {Accumulator.computation_result= (); soft_errors= []}

let ok_unit = return ()

let ok_exn (res : 'a t) : 'a Deferred.t =
  let open Deferred.Let_syntax in
  match%bind res with
  | Ok {Accumulator.computation_result= x; soft_errors= _} ->
      Deferred.return x
  | Error {Hard_fail.hard_error= err; Hard_fail.soft_errors= _} ->
      Error.raise err.error

let error_string message =
  Deferred.return
    (Error
       { Hard_fail.hard_error=
           Test_error.raw_internal_error (Error.of_string message)
       ; soft_errors= [] })

let errorf format = Printf.ksprintf error_string format

let soft_error res err =
  Deferred.return
    (Ok
       { Accumulator.computation_result= res
       ; soft_errors= [Test_error.raw_internal_error err] })

let hard_error err =
  Deferred.return
    (Error
       { Hard_fail.hard_error= Test_error.raw_internal_error err
       ; soft_errors= [] })

let or_error_to_hard_malleable_error (or_err : 'a Deferred.Or_error.t) : 'a t =
  let open Deferred.Let_syntax in
  match%map or_err with
  | Ok x ->
      Ok {Accumulator.computation_result= x; soft_errors= []}
  | Error err ->
      Error
        { Hard_fail.hard_error= Test_error.raw_internal_error err
        ; soft_errors= [] }

let or_error_to_soft_malleable_error (res : 'a)
    (or_err : 'a Deferred.Or_error.t) : 'a t =
  let open Deferred.Let_syntax in
  match%map or_err with
  | Ok x ->
      Ok {Accumulator.computation_result= x; soft_errors= []}
  | Error err ->
      Ok
        { Accumulator.computation_result= res
        ; soft_errors= [Test_error.raw_internal_error err] }

(* 
'a Malleable_error.t list -> 'a list Malleable_error.t
 *)
(* let combine_errors (error_list : 'a Malleable_error.t list ) : 'a list Malleable_error.t = 
  Deferred.map (Deferred.all error_list) ~f:(combine_errors_helper)

let combine_errors_helper (error_list : ('a Accumulator.t, Hard_fail.t) Result.t list ) : (('a list Accumulator.t, Hard_fail.t) Result.t) =
  List.fold_left error_list ~init:(return_without_deferred []) ~f:combine_errors_helper3

let combine_errors_helper3 (fold_acc : ('a list Accumulator.t, Hard_fail.t) Result.t ) (mall_err: 'a Malleable_error.t) = *)

let combine_errors (malleable_errors : 'a t list) : 'a list t =
  let open T.Let_syntax in
  let%map values =
    List.fold_left malleable_errors ~init:(return []) ~f:(fun acc el ->
        let%bind t = acc in
        let%map h = el in
        h :: t )
  in
  List.rev values

let try_with ?(backtrace = false) (f : unit -> 'a) : 'a t =
  try
    Deferred.return
      (Ok {Accumulator.computation_result= f (); soft_errors= []})
  with exn ->
    Deferred.return
      (Error
         { Hard_fail.hard_error=
             Test_error.raw_internal_error
               (Error.of_exn exn
                  ?backtrace:(if backtrace then Some `Get else None))
         ; soft_errors= [] })

let rec malleable_error_list_iter ls ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return ()
  | h :: t ->
      let%bind () = f h in
      malleable_error_list_iter t ~f

let rec malleable_error_list_map ls ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return []
  | h :: t ->
      let%bind h' = f h in
      let%map t' = malleable_error_list_map t ~f in
      h' :: t'

let rec malleable_error_list_fold_left_while ls ~init ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return init
  | h :: t -> (
      match%bind f init h with
      | `Stop init' ->
          return init'
      | `Continue init' ->
          malleable_error_list_fold_left_while t ~init:init' ~f )

let malleable_error_of_option opt msg : 'a t =
  Option.value_map opt
    ~default:
      (Deferred.return
         (Error
            { Hard_fail.hard_error=
                Test_error.raw_internal_error (Error.of_string msg)
            ; Hard_fail.soft_errors= [] }))
    ~f:T.return

let lift_error_set (type a) (m : a t) :
    (a * Test_error.Set.t, Test_error.Set.t) Deferred.Result.t =
  let open Deferred.Let_syntax in
  let internal_error err = Test_error.Internal_error err in
  let internal_error_set hard_errors soft_errors =
    { Test_error.Set.hard_errors= List.map hard_errors ~f:internal_error
    ; soft_errors= List.map soft_errors ~f:internal_error }
  in
  match%map m with
  | Ok {Accumulator.computation_result; soft_errors} ->
      Ok (computation_result, internal_error_set [] soft_errors)
  | Error {Hard_fail.hard_error; soft_errors} ->
      Error (internal_error_set [hard_error] soft_errors)

(* Unit tests to follow *)

(* we derive custom equality and comparisions for our result type, as the
 * default behavior of ppx_assert is to use polymorphic equality and comparisons
 * for results (as to why, I have no clue) *)
type 'a inner = ('a Accumulator.t, Hard_fail.t) Result.t [@@deriving sexp_of]

let equal_inner equal a b =
  match (a, b) with
  | Ok a', Ok b' ->
      Accumulator.equal equal a' b'
  | Error a', Error b' ->
      Hard_fail.equal a' b'
  | _ ->
      false

let compare_inner compare a b =
  match (a, b) with
  | Ok a', Ok b' ->
      Accumulator.compare compare a' b'
  | Error a', Error b' ->
      Hard_fail.compare a' b'
  | Ok _, Error _ ->
      -1
  | Error _, Ok _ ->
      1

let%test_unit "error_monad_unit_test_1" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test1 =
        let open T.Let_syntax in
        let f nm =
          let%bind n = nm in
          Deferred.return
            (Ok {Accumulator.computation_result= n + 1; soft_errors= []})
        in
        f (f (f (f (f (return 0)))))
      in
      [%test_eq: int inner] ~equal:(equal_inner Int.equal) test1
        (Ok {Accumulator.computation_result= 5; soft_errors= []}) )

let%test_unit "error_monad_unit_test_2" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test2 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok {Accumulator.computation_result= (); soft_errors= []})
        in
        Deferred.return
          (Ok {Accumulator.computation_result= "123"; soft_errors= []})
      in
      [%test_eq: string inner] ~equal:(equal_inner String.equal) test2
        (Ok {Accumulator.computation_result= "123"; soft_errors= []}) )

let%test_unit "error_monad_unit_test_3" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test3 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors=
                   [Test_error.raw_internal_error (Error.of_string "a")] })
        in
        Deferred.return
          (Ok
             { Accumulator.computation_result= "123"
             ; soft_errors=
                 [Test_error.raw_internal_error (Error.of_string "b")] })
      in
      [%test_eq: string inner] ~equal:(equal_inner String.equal) test3
        (Ok
           { Accumulator.computation_result= "123"
           ; soft_errors=
               List.map ["a"; "b"]
                 ~f:(Fn.compose Test_error.raw_internal_error Error.of_string)
           }) )

let%test_unit "error_monad_unit_test_4" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test4 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok {Accumulator.computation_result= (); soft_errors= []})
        in
        Deferred.return
          (Error
             { Hard_fail.hard_error=
                 Test_error.raw_internal_error (Error.of_string "xyz")
             ; soft_errors= [] })
      in
      [%test_eq: string inner] ~equal:(equal_inner String.equal) test4
        (Error
           { Hard_fail.hard_error=
               Test_error.raw_internal_error (Error.of_string "xyz")
           ; soft_errors= [] }) )

let%test_unit "error_monad_unit_test_5" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test5 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors=
                   [Test_error.raw_internal_error (Error.of_string "a")] })
        in
        Deferred.return
          (Error
             { Hard_fail.hard_error=
                 Test_error.raw_internal_error (Error.of_string "xyz")
             ; soft_errors= [] })
      in
      [%test_eq: string inner] ~equal:(equal_inner String.equal) test5
        (Error
           { Hard_fail.hard_error=
               Test_error.raw_internal_error (Error.of_string "xyz")
           ; soft_errors= [Test_error.raw_internal_error (Error.of_string "a")]
           }) )

let%test_unit "error_monad_unit_test_6" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test6 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors=
                   [Test_error.raw_internal_error (Error.of_string "a")] })
        in
        Deferred.return
          (Error
             { Hard_fail.hard_error=
                 Test_error.raw_internal_error (Error.of_string "xyz")
             ; soft_errors=
                 [Test_error.raw_internal_error (Error.of_string "b")] })
      in
      [%test_eq: string inner] ~equal:(equal_inner String.equal) test6
        (Error
           { Hard_fail.hard_error=
               Test_error.raw_internal_error (Error.of_string "xyz")
           ; soft_errors=
               [ Test_error.raw_internal_error (Error.of_string "a")
               ; Test_error.raw_internal_error (Error.of_string "b") ] }) )
