(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Names
open Conversion
open Util
open Values
open Nativevalues
open Nativecode
open Environ

(** This module implements the conversion test by compiling to OCaml code *)

type 'a fail = { fail : 'r. 'a -> 'r }

exception NotConvertible

let fail_check state check box = match state with
| Result.Ok state -> (state, check, box)
| Result.Error None -> raise NotConvertible
| Result.Error (Some err) -> box.fail err

let convert_instances ~flex u1 u2 (state, check, box) =
  let state, check = Conversion.convert_instances ~flex u1 u2 (state, check) in
  fail_check state check box

let sort_cmp_universes env pb s1 s2 (state, check, box) =
  let state, check = Conversion.sort_cmp_universes env pb s1 s2 (state, check) in
  fail_check state check box

let rec conv_val env pb lvl v1 v2 cu =
  if v1 == v2 then cu
  else
    match kind_of_value v1, kind_of_value v2 with
    | Vfun f1, Vfun f2 ->
        let v = mk_rel_accu lvl in
        conv_val env CONV (lvl+1) (f1 v) (f2 v) cu
    | Vfun _f1, _ ->
      conv_val env CONV lvl v1 (eta_expand v2) cu
    | _, Vfun _f2 ->
        conv_val env CONV lvl (eta_expand v1) v2 cu
    | Vaccu k1, Vaccu k2 ->
        conv_accu env pb lvl k1 k2 cu
    | Vprod(_,d1,c1), Vprod(_,d2,c2) ->
       let cu = conv_val env CONV lvl d1 d2 cu in
       let v = mk_rel_accu lvl in
       conv_val env pb (lvl + 1) (apply c1 v) (apply c2 v) cu
    | Vconst i1, Vconst i2 ->
        if Int.equal i1 i2 then cu else raise NotConvertible
    | Vint64 i1, Vint64 i2 ->
      if Int64.equal i1 i2 then cu else raise NotConvertible
    | Vfloat64 f1, Vfloat64 f2 ->
        if Float64.(equal (of_float f1) (of_float f2)) then cu
        else raise NotConvertible
    | Vstring s1, Vstring s2 ->
        if Pstring.equal s1 s2 then cu
        else raise NotConvertible
    | Varray t1, Varray t2 ->
      let len = Parray.length_int t1 in
      if not (Int.equal len (Parray.length_int t2)) then raise NotConvertible;
      Parray.fold_left2 (fun cu v1 v2 -> conv_val env CONV lvl v1 v2 cu) cu t1 t2
    | Vblock b1, Vblock b2 ->
        let n1 = block_size b1 in
        let n2 = block_size b2 in
        if not (Int.equal (block_tag b1) (block_tag b2)) || not (Int.equal n1 n2) then
          raise NotConvertible;
        let rec aux lvl max b1 b2 i cu =
          if Int.equal i max then
            conv_val env CONV lvl (block_field b1 i) (block_field b2 i) cu
          else
            let cu = conv_val env CONV lvl (block_field b1 i) (block_field b2 i) cu in
            aux lvl max b1 b2 (i+1) cu
        in
        aux lvl (n1-1) b1 b2 0 cu
    | (Vfix e | Vcofix e), _ | _, (Vfix e | Vcofix e) -> Empty.abort e
    | (Vaccu _ | Vprod _ | Vconst _ | Vint64 _ | Vfloat64 _ | Vstring _ | Varray _ | Vblock _), _ -> raise NotConvertible

and conv_accu env pb lvl k1 k2 cu =
  let n1 = accu_nargs k1 in
  let n2 = accu_nargs k2 in
  if not (Int.equal n1 n2) then raise NotConvertible;
  if Int.equal n1 0 then
    conv_atom env pb lvl (atom_of_accu k1) (atom_of_accu k2) cu
  else
    let cu = conv_atom env pb lvl (atom_of_accu k1) (atom_of_accu k2) cu in
    List.fold_right2 (conv_val env CONV lvl) (args_of_accu k1) (args_of_accu k2) cu

and conv_atom env pb lvl a1 a2 cu =
  if a1 == a2 then cu
  else
    match a1, a2 with
    | Aevar (ev1, args1), Aevar (ev2, args2) ->
      if Evar.equal ev1 ev2 then
        Array.fold_right2 (conv_val env CONV lvl) args1 args2 cu
      else raise NotConvertible
    | Arel i1, Arel i2 ->
        if Int.equal i1 i2 then cu else raise NotConvertible
    | Aind (ind1,u1), Aind (ind2,u2) ->
       if Ind.CanOrd.equal ind1 ind2 then convert_instances ~flex:false u1 u2 cu
       else raise NotConvertible
    | Aconstant (c1,u1), Aconstant (c2,u2) ->
       if Constant.CanOrd.equal c1 c2 then convert_instances ~flex:true u1 u2 cu
       else raise NotConvertible
    | Asort s1, Asort s2 ->
      sort_cmp_universes env pb s1 s2 cu
    | Avar id1, Avar id2 ->
        if Id.equal id1 id2 then cu else raise NotConvertible
    | Acase(a1,ac1,p1,bs1), Acase(a2,ac2,p2,bs2) ->
        if not (Ind.CanOrd.equal a1.asw_ind a2.asw_ind) then raise NotConvertible;
        let cu = conv_accu env CONV lvl ac1 ac2 cu in
        let tbl = a1.asw_reloc in
        let len = Array.length tbl in
        if Int.equal len 0 then conv_val env CONV lvl p1 p2 cu
        else begin
            let cu = conv_val env CONV lvl p1 p2 cu in
            let max = len - 1 in
            let rec aux i cu =
              let tag,arity = tbl.(i) in
              let ci =
                if Int.equal arity 0 then mk_const tag
                else mk_block tag (mk_rels_accu lvl arity) in
              let bi1 = apply bs1 ci and bi2 = apply bs2 ci in
              if Int.equal i max then conv_val env CONV (lvl + arity) bi1 bi2 cu
              else aux (i+1) (conv_val env CONV (lvl + arity) bi1 bi2 cu) in
            aux 0 cu
          end
    | Afix(t1,f1,rp1,s1), Afix(t2,f2,rp2,s2) ->
        if not (Int.equal s1 s2) || not (Array.equal Int.equal rp1 rp2) then raise NotConvertible;
        if f1 == f2 then cu
        else conv_fix env lvl t1 f1 t2 f2 cu
    | Acofix (t1, f1, s1, args1, _), Acofix (t2, f2, s2, args2, _) ->
        if not (Int.equal s1 s2) then raise NotConvertible;
        if f1 == f2 && args1 == args2 then cu
        else if not (Int.equal (Array.length f1) (Array.length f2) && Int.equal (Array.length args1) (Array.length args2)) then
          raise NotConvertible
        else
          Array.fold_left2 (fun cu v1 v2 -> conv_val env CONV lvl v1 v2 cu) (conv_fix env lvl t1 f1 t2 f2 cu) args1 args2
    | Aproj((ind1, i1), ac1), Aproj((ind2, i2), ac2) ->
       if not (Ind.CanOrd.equal ind1 ind2 && Int.equal i1 i2) then raise NotConvertible
       else conv_accu env CONV lvl ac1 ac2 cu
    | Arel _, _ | Aind _, _ | Aconstant _, _ | Asort _, _ | Avar _, _
    | Acase _, _ | Afix _, _ | Acofix _, _
    | Aproj _, _ | Aevar _, _ -> raise NotConvertible

(* Precondition length t1 = length f1 = length f2 = length t2 *)
and conv_fix env lvl t1 f1 t2 f2 cu =
  let len = Array.length f1 in
  let max = len - 1 in
  let fargs = mk_rels_accu lvl len in
  let flvl = lvl + len in
  let rec aux i cu =
    let cu = conv_val env CONV lvl t1.(i) t2.(i) cu in
    let fi1 = napply f1.(i) fargs in
    let fi2 = napply f2.(i) fargs in
    if Int.equal i max then conv_val env CONV flvl fi1 fi2 cu
    else aux (i+1) (conv_val env CONV flvl fi1 fi2 cu) in
  aux 0 cu

let w_native_disabled = CWarnings.create_warning
    ~from:[CWarnings.CoreCategories.native_compiler] ~name:"native-compiler-disabled"
    ()

let warn_no_native_compiler =
  let open Pp in
  CWarnings.create_in w_native_disabled
         (fun () -> strbrk "Native compiler is disabled," ++
                      strbrk " falling back to VM conversion test.")

let native_conv_gen (type err) pb sigma env (state, check) t1 t2 =
  Nativelib.link_libraries ();
  let ml_filename, prefix = Nativelib.get_ml_filename () in
  let code, upds = mk_conv_code env sigma prefix t1 t2 in
  let fn = Nativelib.compile ml_filename code ~profile:false in
  debug_native_compiler (fun () -> Pp.str "Running test...");
  let t0 = Sys.time () in
  let (rt1, rt2) = Nativelib.execute_library ~prefix fn upds in
  let rt1 = Option.get rt1 and rt2 = Option.get rt2 in
  let t1 = Sys.time () in
  let time_info = Format.sprintf "Evaluation done in %.5f@." (t1 -. t0) in
  debug_native_compiler (fun () -> Pp.str time_info);
  (* TODO change 0 when we can have de Bruijn *)
  let exception Error of err in
  let box = { fail = fun e -> raise (Error e) } in
  try Result.Ok (pi1 (conv_val env pb 0 rt1 rt2 (state, check, box)))
  with
  | NotConvertible -> Result.Error None
  | Error e -> Result.Error (Some e)

let native_conv_gen pb sigma env univs t1 t2 =
  if not (typing_flags env).Declarations.enable_native_compiler then
    let () = warn_no_native_compiler () in
    Vconv.vm_conv_gen pb sigma env univs t1 t2
  else native_conv_gen pb sigma env univs t1 t2

(* Wrapper for [native_conv] above *)
let native_conv cv_pb sigma env t1 t2 =
  let univs = Environ.universes env in
  let b =
    if cv_pb = CUMUL then Constr.leq_constr_univs univs t1 t2
    else Constr.eq_constr_univs univs t1 t2
  in
  if b then Result.Ok ()
  else
    let state = (univs, checked_universes) in
    let t1 = Term.it_mkLambda_or_LetIn t1 (Environ.rel_context env) in
    let t2 = Term.it_mkLambda_or_LetIn t2 (Environ.rel_context env) in
    match native_conv_gen cv_pb sigma env state t1 t2 with
    | Result.Ok (_ : UGraph.t) -> Result.Ok ()
    | Result.Error None -> Result.Error ()
    | Result.Error (Some _) ->
      (* checked_universes cannot raise this *)
      assert false
