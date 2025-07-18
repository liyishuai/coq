(* Bug 5568, don't warn for notations in repeated module import *)

Module foo.
Notation compose := (fun g f => g f).
Notation "g & f" := (compose g f) (at level 10).
End foo.

Import foo.
Import foo.
Import foo.

(**********************************************************************)
(* Notations for if and let (submitted by Roland Zumkeller)           *)

Notation "a ? b ; c" := (if a then b else c) (at level 10).

Check (true ? 0 ; 1).
Check if true as x return (if x then nat else bool) then 0 else true.

Notation "'proj1' t" := (let (a,_) := t in a) (at level 1).

Check (fun e : nat * nat => proj1 e).

Notation "'decomp' a 'as' x , y 'in' b" := (let (x,y) := a in b) (at level 1).

Check (decomp (true,true) as t, u in (t,u)).

(**********************************************************************)
(* Behaviour wrt to binding variables (submitted by Roland Zumkeller) *)

Section A.

Notation "! A" := (forall _:nat, A) (at level 60).

Check ! (0=0).
Check forall n, n=0.
Check forall n:nat, 0=0.

End A.

(**********************************************************************)
(* Behaviour wrt to binding variables (cf bug report #1186)           *)

Section B.

Notation "# A" := (forall n:nat, n=n->A) (at level 60).
Check forall n:nat, # (n=n).

Notation "## A" := (forall n n0:nat, n=n0->A) (at level 60).
Check forall n n0:nat, ## (n=n0).

Notation "### A" :=
 (forall n n0:nat, match n with O => True | S n => n=n0 end ->A) (at level 60).
Check forall n n0:nat, ### (n=n0).

End B.

(**********************************************************************)
(* Check recursive notations                                          *)

Notation "[ x ; .. ; y ]" := (cons x .. (cons y nil) ..).
Check [1;2;4].

Reserved Notation "( x ; y , .. , z )" (at level 0).
Notation "( x ; y , .. , z )" := (pair .. (pair x y) .. z).
Check (1;2,4).

(* Check basic notations involving "match" *)

Section C.

Notation "'ifzero' n" := (match n with 0 => true | S _ => false end)
  (at level 0, n at level 0).
Check (ifzero 3).

Notation "'pred' n" := (match n with 0 => 0 | S n' => n' end)
  (at level 0, n at level 0).
Check (pred 3).
Check (fun n => match n with 0 => 0 | S n => n end).
Check (fun n => match n with S p as x => p | _ => 0 end).

Notation "'ifn' x 'is' 'succ' n 'then' t 'else' u" :=
  (match x with O => u | S n => t end) (at level 0, u at level 0).
Check fun x => ifn x is succ n then n else 0.

End C.

(* Check correction of bug #1179 *)

Notation "1 -" := true (at level 0).
Check 1-.

(**********************************************************************)
(* Check ill-formed recursive notations *)

(* Recursive variables not part of a recursive pattern *)
Fail Notation "( x , y , .. , z )" := (pair x .. (pair y z) ..).

(* No recursive notation *)
Fail Notation "( x , y , .. , z )" := (pair x (pair y z)).

(* Left-unbound variable *)
Fail Notation "( x , y , .. , z )" := (pair x .. (pair y w) ..).

(* Right-unbound variable *)
Notation "( x , y , .. , z )" := (pair y .. (pair z 0) ..) (only parsing).

(* Not the right kind of recursive pattern *)
Fail Notation "( x , y , .. , z )" := (ex (fun z => .. (ex (fun y => x)) ..)).
Fail Notation "( x -- y , .. , z )" := (pair y .. (pair z 0) ..)
  (y closed binder, z closed binder).

(* No separator allowed with open binders *)
Fail Notation "( x -- y , .. , z )" := (ex (fun z => .. (ex (fun y => x)) ..))
  (y binder, z binder).

(* Ends of pattern do not match *)
Fail Notation "( x , y , .. , z )" := (pair y .. (pair (plus z) 0) ..).
Fail Notation "( x , y , .. , z )" := (pair y .. (plus z 0) ..).
Fail Notation "( x1 , x2 , y , .. , z )" := (y y .. (x2 z 0) ..).
Fail Notation "( x1 , x2 , y , .. , z )" := (x1 y .. (x2 z 0) ..).

(* Ends of pattern are the same *)
Fail Notation "( x , y , .. , z )" := (pair .. (pair (pair y z) x) .. x).

(**********************************************************************)
(* Check preservation of scopes at printing time *)

Notation SUM := sum.
Check SUM (nat*nat) nat.

(**********************************************************************)
(* Check preservation of implicit arguments at printing time *)

Notation FST := fst.
Check FST (0;1).

(**********************************************************************)
(* Check notations for references with activated or deactivated       *)
(* implicit arguments                                                 *)

Notation Nil := @nil.
Check Nil.

Notation NIL := nil.
Check NIL : list nat.


(**********************************************************************)
(* Test printing of notation with coercions in scope of a coercion    *)

Open Scope nat_scope.

Coercion is_true := fun b => b=true.
Coercion of_nat n := match n with 0 => true | _ => false end.
Notation "'I' x" := (of_nat (S x) || true)%bool (at level 10).

Check (false && I 3)%bool /\ I 6.

(**********************************************************************)
(* Check notations with several recursive patterns                    *)

Notation "[| x , y , .. , z ; a , b , .. , c |]" :=
  (pair (pair .. (pair x y) .. z) (pair .. (pair a b) .. c)).
Check [|1,2,3;4,5,6|].

Notation "[| t * ( x , y , .. , z ) ; ( a , b , .. , c )  * u |]" :=
  (pair (pair .. (pair (pair t x) (pair t y)) .. (pair t z))
        (pair .. (pair (pair a u) (pair b u)) .. (pair c u)))
  (t at level 39).
Check [|0*(1,2,3);(4,5,6)*false|].

(**********************************************************************)
(* Test recursive notations involving applications                    *)

Module Application.

Notation "{| f ; x ; .. ; y |}" := ( .. (f x) .. y).

(* Application to a variable *)

Check fun f => {| f; 0; 1; 2 |} : nat.

(* Application to a fun *)

Check {| (fun x => x+x); 0 |}.

(* Application to a reference *)

Axiom op : nat -> nat -> nat.
Check {| op; 0; 1 |}.

(* Interaction with coercion *)

Axiom c : nat -> bool.
Coercion c : nat >-> bool.
Check false = {| c; 0 |}.

End Application.

(* Check notations in cases patterns *)

Notation SOME := Some.
Notation NONE := None.
Check (fun x => match x with SOME x => x | NONE => 0 end).

Notation NONE2 := (@None _).
Notation SOME2 := (@Some _).
Check (fun x => match x with SOME2 x => x | NONE2 => 0 end).

Notation NONE3 := @None.
Notation SOME3 := @Some.
Check (fun x => match x with SOME3 _ x => x | NONE3 _ => 0 end).

Notation "a :'" := (cons a) (at level 10).

Check (fun x => match x with | nil => NONE | h :' t => SOME3 _ t end).

(* Check correct matching of "Type" in notations. Of course the
   notation denotes a term that will be reinterpreted with a different
   universe than the actual one; but it would be the same anyway
   without a notation *)

Notation s := Type.
Check s.

(* Test bug #2835: notations were not uniformly managed under prod and lambda *)

Open Scope nat_scope.

Notation "'foo' n" := (S n) (at level 50): nat_scope.

Check (foo 9).
Check (fun _ : nat => 9).

(* Checking parsing and printing of numerical and non-numerical notations for eq_refl *)

(* This notation was not correctly printed until Pierre B.'s
   improvements to the interpretation of patterns *)

Notation "'ONE'" := eq_refl.
Check fun (x:nat) (p : x=x) => match p with ONE => ONE end = p.

(* This one used to failed at parsing until now *)

Notation "1" := eq_refl.
Check fun (x:nat) (p : x=x) => match p with 1 => 1 end = p.

(* Check bug 5693 *)

Module M.
Definition A := 0.
Definition bar (a b : nat) := plus a b.
Notation "" := A (format "", only printing).
Check (bar A 0).
End M.

(* Check eq notations *)
Module EqNotationsCheck.
  Import EqNotations.
  Section nd.
    Context (A : Type) (x : A) (P : A -> Type)
            (y : A) (p : x = y) (v : P x) (v' : P y).

    Check let k : P y := rew p in v in k.
    Check let k : P y := rew -> p in v in k.
    Check let k : P x := rew <- p in v' in k.
    Check let k : P y := rew [P] p in v in k.
    Check let k : P y := rew -> [P] p in v in k.
    Check let k : P x := rew <- [P] p in v' in k.
    Check let k : P y := rew [fun y => P y] p in v in k.
    Check let k : P y := rew -> [fun y => P y] p in v in k.
    Check let k : P x := rew <- [fun y => P y] p in v' in k.
    Check let k : P y := rew [fun (y : A) => P y] p in v in k.
    Check let k : P y := rew -> [fun (y : A) => P y] p in v in k.
    Check let k : P x := rew <- [fun (y : A) => P y] p in v' in k.
  End nd.
  Section dep.
    Context (A : Type) (x : A) (P : forall y, x = y -> Type)
            (y : A) (p : x = y) (P' : forall x, y = x -> Type)
            (v : P x eq_refl) (v' : P' y eq_refl).

    Check let k : P y p := rew dependent p in v in k.
    Check let k : P y p := rew dependent -> p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- p in v' in k.
    Check let k : P y p := rew dependent [P] p in v in k.
    Check let k : P y p := rew dependent -> [P] p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- [P'] p in v' in k.
    Check let k : P y p := rew dependent [fun y p => P y p] p in v in k.
    Check let k : P y p := rew dependent -> [fun y p => P y p] p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- [fun y p => P' y p] p in v' in k.
    Check let k : P y p := rew dependent [fun y p => id (P y p)] p in v in k.
    Check let k : P y p := rew dependent -> [fun y p => id (P y p)] p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- [fun y p => id (P' y p)] p in v' in k.
    Check let k : P y p := rew dependent [(fun (y : A) (p : x = y) => P y p)] p in v in k.
    Check let k : P y p := rew dependent -> [(fun (y : A) (p : x = y) => P y p)] p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- [(fun (x : A) (p : y = x) => P' x p)] p in v' in k.
    Check let k : P y p := rew dependent [(fun (y : A) (p : x = y) => id (P y p))] p in v in k.
    Check let k : P y p := rew dependent -> [(fun (y : A) (p : x = y) => id (P y p))] p in v in k.
    Check let k : P' x (eq_sym p) := rew dependent <- [(fun (x : A) (p : y = x) => id (P' x p))] p in v' in k.
    Check match p as x in _ = a return P a x with
          | eq_refl => v
          end.
    Check match eq_sym p as p' in _ = a return P' a p' with
          | eq_refl => v'
          end.
    Check match p as x in _ = a return id (P a x) with
          | eq_refl => v
          end.
    Check match eq_sym p as p' in _ = a return id (P' a p') with
          | eq_refl => v'
          end.
  End dep.
End EqNotationsCheck.
