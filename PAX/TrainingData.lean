-- PAX TrainingData — PAX-Coder fine-tuning dataset extractor
-- Ahmad Ali Parr · PAX Architecture

namespace PAX.TrainingData

/-- One training example: (prompt, Lean 4 proof, PTX kernel, Futhark spec, constraints) -/
structure TrainingExample where
  id             : String
  prompt         : String
  lean_theorem   : String
  lean_proof     : String
  ptx_kernel     : String
  futhark_kernel : String
  spec_section   : String
  constraints    : List String
  arch           : String
  category       : String
  deriving Repr

/-- Source files to extract from -/
def sourceFiles : List (String × String × String) :=
  [ ("PAX/Float16_Rounding.lean",    "fp16",        "sm_86")
  , ("PAX/WMMA.lean",                "gemm",        "sm_86")
  , ("PAX/PipelineDAG.lean",         "pipeline",    "sm_86")
  , ("PAX/ConstraintDAG.lean",       "architecture","all")
  , ("PAX/IR_DAG.lean",              "architecture","all")
  , ("src/rtx_gemm_ptx.cu",          "gemm",        "sm_86")
  , ("src/rtx_gemm_pipeline.cu",     "pipeline",    "sm_86")
  , ("src/rtx_gemm_epilogue.cu",     "epilogue",    "sm_86")
  , ("src/pax_kernel.fut",           "gemm",        "sm_86")
  , ("docs/PAX_ARCHITECTURE.md",     "architecture","all")
  ]

/-- Proof obligation tags per category -/
def constraintsFor (category : String) : List String :=
  match category with
  | "fp16"        => ["PO4", "PO5"]
  | "gemm"        => ["PO1", "PO3", "PO5", "PO8"]
  | "pipeline"    => ["PO4", "PO6", "PO7"]
  | "epilogue"    => ["PO8"]
  | "index_space" => ["PO1", "PO2"]
  | "warp"        => ["PO3", "PO4"]
  | _             => ["PO8"]

/-- Canonical prompt templates by category -/
def promptFor (category : String) : String :=
  match category with
  | "fp16"     => "Write a Lean 4 formalization of IEEE-754 binary16 RNE with proven |round(x)-x| ≤ 0.5 ulp for FP16 GEMM on Ampere sm_86."
  | "gemm"     => "Write a verified GEMM kernel for RTX 3080 sm_86 using mma.sync.aligned.m16n8k8 FP16→FP32 with Lean 4 correctness proof."
  | "pipeline" => "Define a 3-stage async cp.async pipeline in Lean 4 with proven throughput bound ≥ (1-1/stages)×min(compute_bw,memory_bw)."
  | "epilogue" => "Formalize in-register Bias+GeLU fusion with proven |GeLU_approx - GeLU_exact| ≤ 0.001."
  | "warp"     => "Write warp-level reduction using shfl.sync.xor.b32 with Lean 4 correctness proof for dot product."
  | _          => "Explain PAX Architecture axiom-to-proof-obligation mapping."

end PAX.TrainingData
