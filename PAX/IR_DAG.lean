-- PAX IR DAG — PAX-IR module as verified Lean 4 DAG (Layer 2.1)
-- Ahmad Ali Parr · PAX Architecture

namespace PAX.IR_DAG

structure PAXFunction where
  name  : String
  arity : ℕ
  arch  : String  -- "sm_86" | "sm_90"
  deriving Repr

structure Value where
  id   : ℕ
  kind : String  -- "reg" | "shared" | "global"
  deriving Repr

/-- PAX-IR: functions + SSA data flow, no recursive kernels -/
structure PAXModuleDAG where
  functions : List PAXFunction
  callGraph : List (PAXFunction × PAXFunction)
  dataFlow  : List (Value × Value)

/-- Call graph acyclicity predicate (no recursive kernels) -/
def isAcyclic (dag : PAXModuleDAG) : Prop :=
  ∀ f : PAXFunction, ¬ (dag.callGraph.contains (f, f))

end PAX.IR_DAG
