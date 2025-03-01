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

type t = {
  tr_var : Id.Pred.t;
  tr_cst : Cpred.t;
  tr_prj : PRpred.t;
}

let empty = {
  tr_var = Id.Pred.empty;
  tr_cst = Cpred.empty;
  tr_prj = PRpred.empty;
}

let full = {
  tr_var = Id.Pred.full;
  tr_cst = Cpred.full;
  tr_prj = PRpred.full;
}

let is_empty ts =
  Id.Pred.is_empty ts.tr_var &&
  Cpred.is_empty ts.tr_cst &&
  PRpred.is_empty ts.tr_prj

let is_transparent_variable ts id =
  Id.Pred.mem id ts.tr_var

let is_transparent_constant ts cst =
  Cpred.mem cst ts.tr_cst

let is_transparent_projection ts p =
  PRpred.mem p ts.tr_prj
