-- PAX ConstraintDAG — HyperKitty 7-node pipeline as a verified Lean 4 structure
-- Ahmad Ali Parr · PAX Architecture · sm_86

import Mathlib.Data.Finset.Basic

namespace PAX.ConstraintDAG

/-- The 7 nodes of the HyperKitty Constraint DAG -/
inductive ConstraintNode : Type
  | Input      -- 🧠 Raw kernel request
  | Memory     -- 📚 Abjad/weight store
  | Retrieval  -- 🔍 Proof obligation lookup
  | Transform  -- ⚙  PTX/Futhark generation
  | Constraint -- ⚖  Invariant checking
  | Proof      -- 🔐 Lean 4 verification
  | Output     -- 🌐 Sealed kernel + receipt
  deriving DecidableEq, Repr

/-- DAG as adjacency relation -/
def isEdge : ConstraintNode → ConstraintNode → Prop
  | .Input,      .Memory     => True
  | .Memory,     .Retrieval  => True
  | .Retrieval,  .Transform  => True
  | .Transform,  .Constraint => True
  | .Constraint, .Proof      => True
  | .Proof,      .Output     => True
  | _,           _           => False

instance : DecidablePred (isEdge n) := by
  intro n m
  cases n <;> cases m <;> simp [isEdge] <;> exact inferInstance

/-- Topological order for the 7-node chain -/
def topoOrder : ConstraintNode → ℕ
  | .Input      => 0
  | .Memory     => 1
  | .Retrieval  => 2
  | .Transform  => 3
  | .Constraint => 4
  | .Proof      => 5
  | .Output     => 6

/-- Acyclicity: edges only go forward in topo order -/
theorem dag_acyclic (n m : ConstraintNode) (h : isEdge n m) :
    topoOrder n < topoOrder m := by
  cases n <;> cases m <;> simp [isEdge, topoOrder] at *

/-- Single source -/
theorem single_source (n : ConstraintNode) :
    (∃ m, isEdge m n) → n ≠ .Input := by
  cases n <;> simp [isEdge]

/-- Single sink -/
theorem single_sink (n : ConstraintNode) :
    (∃ m, isEdge n m) → n ≠ .Output := by
  cases n <;> simp [isEdge]

end PAX.ConstraintDAG
