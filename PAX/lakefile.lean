import Lake
open Lake DSL

package paxCoder where
  name := "pax-coder"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "master"

lean_lib PAX where
  roots := #[
    `PAX.ConstraintDAG,
    `PAX.IR_DAG,
    `PAX.PipelineDAG,
    `PAX.Float16_Rounding,
    `PAX.WMMA,
    `PAX.TrainingData
  ]
