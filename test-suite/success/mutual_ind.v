(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)
(* Definition mutuellement inductive et dependante *)

 Record signature : Type :=
   {sort : Set;
    sort_beq : sort -> sort -> bool;
    sort_beq_refl : forall f : sort, true = sort_beq f f;
    sort_beq_eq : forall f1 f2 : sort, true = sort_beq f1 f2 -> f1 = f2;
    fsym :> Set;
    fsym_type : fsym -> list sort * sort;
    fsym_beq : fsym -> fsym -> bool;
    fsym_beq_refl : forall f : fsym, true = fsym_beq f f;
    fsym_beq_eq : forall f1 f2 : fsym, true = fsym_beq f1 f2 -> f1 = f2}.


 Parameter F : signature.

  Definition vsym := (sort F * nat)%type.

  Definition vsym_sort := fst (A:=sort F) (B:=nat).
  Definition vsym_nat := snd (A:=sort F) (B:=nat).


  Inductive term : sort F -> Set :=
    | term_var : forall v : vsym, term (vsym_sort v)
    | term_app :
        forall f : F,
        list_term (fst (fsym_type F f)) -> term (snd (fsym_type F f))
with list_term : list (sort F) -> Set :=
  | term_nil : list_term nil
  | term_cons :
      forall (s : sort F) (l : list (sort F)),
      term s -> list_term l -> list_term (s :: l).

