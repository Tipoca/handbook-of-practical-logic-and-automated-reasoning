(* ========================================================================= *)
(* Prenex and Skolem normal forms.                                           *)
(*                                                                           *)
(* Copyright (c) 2003-2007, John Harrison. (See "LICENSE.txt" for details.)  *)
(* ========================================================================= *)

(* ------------------------------------------------------------------------- *)
(* Routine simplification. Like "psimplify" but with quantifier clauses.     *)
(* ------------------------------------------------------------------------- *)

let simplify1 fm =
  match fm with
    Forall(x,p) -> if mem x (fv p) then fm else p
  | Exists(x,p) -> if mem x (fv p) then fm else p
  | _ -> psimplify1 fm;;

let rec simplify fm =
  match fm with
    Not p -> simplify1 (Not(simplify p))
  | And(p,q) -> simplify1 (And(simplify p,simplify q))
  | Or(p,q) -> simplify1 (Or(simplify p,simplify q))
  | Imp(p,q) -> simplify1 (Imp(simplify p,simplify q))
  | Iff(p,q) -> simplify1 (Iff(simplify p,simplify q))
  | Forall(x,p) -> simplify1(Forall(x,simplify p))
  | Exists(x,p) -> simplify1(Exists(x,simplify p))
  | _ -> fm;;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
simplify <<(forall x y. P(x) \/ (P(y) /\ false)) ==> exists z. Q>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Negation normal form.                                                     *)
(* ------------------------------------------------------------------------- *)

let rec nnf fm =
  match fm with
    And(p,q) -> And(nnf p,nnf q)
  | Or(p,q) -> Or(nnf p,nnf q)
  | Imp(p,q) -> Or(nnf(Not p),nnf q)
  | Iff(p,q) -> Or(And(nnf p,nnf q),And(nnf(Not p),nnf(Not q)))
  | Not(Not p) -> nnf p
  | Not(And(p,q)) -> Or(nnf(Not p),nnf(Not q))
  | Not(Or(p,q)) -> And(nnf(Not p),nnf(Not q))
  | Not(Imp(p,q)) -> And(nnf p,nnf(Not q))
  | Not(Iff(p,q)) -> Or(And(nnf p,nnf(Not q)),And(nnf(Not p),nnf q))
  | Forall(x,p) -> Forall(x,nnf p)
  | Exists(x,p) -> Exists(x,nnf p)
  | Not(Forall(x,p)) -> Exists(x,nnf(Not p))
  | Not(Exists(x,p)) -> Forall(x,nnf(Not p))
  | _ -> fm;;

(* ------------------------------------------------------------------------- *)
(* Example of NNF function in action.                                        *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
nnf <<(forall x. P(x))
      ==> ((exists y. Q(y)) <=> exists z. P(z) /\ Q(z))>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Prenex normal form.                                                       *)
(* ------------------------------------------------------------------------- *)

let rec pullquants fm =
  match fm with
    And(Forall(x,p),Forall(y,q)) ->
                          pullq(true,true) fm mk_forall mk_and x y p q
  | Or(Exists(x,p),Exists(y,q)) ->
                          pullq(true,true) fm mk_exists mk_or x y p q
  | And(Forall(x,p),q) -> pullq(true,false) fm mk_forall mk_and x x p q
  | And(p,Forall(y,q)) -> pullq(false,true) fm mk_forall mk_and y y p q
  | Or(Forall(x,p),q) ->  pullq(true,false) fm mk_forall mk_or x x p q
  | Or(p,Forall(y,q)) ->  pullq(false,true) fm mk_forall mk_or y y p q
  | And(Exists(x,p),q) -> pullq(true,false) fm mk_exists mk_and x x p q
  | And(p,Exists(y,q)) -> pullq(false,true) fm mk_exists mk_and y y p q
  | Or(Exists(x,p),q) ->  pullq(true,false) fm mk_exists mk_or x x p q
  | Or(p,Exists(y,q)) ->  pullq(false,true) fm mk_exists mk_or y y p q
  | _ -> fm

and pullq(l,r) fm quant op x y p q =
  let z = variant x (fv fm) in
  let p' = if l then subst (x |=> Var z) p else p
  and q' = if r then subst (y |=> Var z) q else q in
  quant z (pullquants(op p' q'));;

let rec prenex fm =
  match fm with
    Forall(x,p) -> Forall(x,prenex p)
  | Exists(x,p) -> Exists(x,prenex p)
  | And(p,q) -> pullquants(And(prenex p,prenex q))
  | Or(p,q) -> pullquants(Or(prenex p,prenex q))
  | _ -> fm;;

let pnf fm = prenex(nnf(simplify fm));;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
pnf <<(forall x. P(x) \/ R(y))
      ==> exists y z. Q(y) \/ ~(exists z. P(z) /\ Q(z))>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Get the functions in a term and formula.                                  *)
(* ------------------------------------------------------------------------- *)

let rec funcs tm =
  match tm with
    Var x -> []
  | Fn(f,args) -> itlist (union ** funcs) args [f,length args];;

let functions fm =
  atom_union (fun (R(p,a)) -> itlist (union ** funcs) a []) fm;;

(* ------------------------------------------------------------------------- *)
(* Core Skolemization function.                                              *)
(* ------------------------------------------------------------------------- *)

let rec skolem fm fns =
  match fm with
    Exists(y,p) ->
        let xs = fv(fm) in
        let f = variant (if xs = [] then "c_"^y else "f_"^y) fns in
        let fx = Fn(f,map (fun x -> Var x) xs) in
        skolem (subst (y |=> fx) p) (f::fns)
  | Forall(x,p) -> let p',fns' = skolem p fns in Forall(x,p'),fns'
  | And(p,q) -> skolem2 (fun (p,q) -> And(p,q)) (p,q) fns
  | Or(p,q) -> skolem2 (fun (p,q) -> Or(p,q)) (p,q) fns
  | _ -> fm,fns

and skolem2 cons (p,q) fns =
  let p',fns' = skolem p fns in
  let q',fns'' = skolem q fns' in
  cons(p',q'),fns'';;

(* ------------------------------------------------------------------------- *)
(* Overall Skolemization function.                                           *)
(* ------------------------------------------------------------------------- *)

let askolemize fm =
  fst(skolem (nnf(simplify fm)) (map fst (functions fm)));;

let rec specialize fm =
  match fm with
    Forall(x,p) -> specialize p
  | _ -> fm;;

let skolemize fm = specialize(pnf(askolemize fm));;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
skolemize <<exists y. x < y ==> forall u. exists v. x * u < y * v>>;;

skolemize
 <<forall x. P(x)
             ==> (exists y z. Q(y) \/ ~(exists z. P(z) /\ Q(z)))>>;;
END_INTERACTIVE;;
