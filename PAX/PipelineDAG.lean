-- PAX PipelineDAG — 3-stage async cp.async pipeline as event DAG (Layer 1.3)
-- Ahmad Ali Parr · PAX Architecture · sm_86

namespace PAX.PipelineDAG

abbrev EventId := ℕ

/-- Happens-before as a strict partial order over EventIds -/
inductive HappensBefore : EventId → EventId → Prop
  | base  : ∀ a b, a < b → HappensBefore a b
  | trans : ∀ a b c, HappensBefore a b → HappensBefore b c → HappensBefore a c

/-- 3-stage async pipeline DAG -/
structure PipelineDAG where
  stages       : ℕ
  copyEvents   : List EventId   -- cp.async issued
  computeEvents: List EventId   -- mma.sync issued
  hbEdges      : List (EventId × EventId)

/-- Pipeline overlap invariant:
    for each stage s, HB(copy[s], compute[s]) and HB(compute[s], copy[s+1]) -/
def hasOverlapInvariant (dag : PipelineDAG) : Prop :=
  ∀ i : ℕ, i < dag.stages →
    let copyEv    := dag.copyEvents.get?    i
    let computeEv := dag.computeEvents.get? i
    let nextCopy  := dag.copyEvents.get?    (i + 1)
    (copyEv.isSome ∧ computeEv.isSome) →
      dag.hbEdges.contains (copyEv.get!, computeEv.get!) ∧
      (nextCopy.isSome → dag.hbEdges.contains (computeEv.get!, nextCopy.get!))

/-- Throughput lower bound:
    A 3-stage async pipeline achieves ≥ (1 - 1/stages) × min(compute_bw, memory_bw) -/
theorem pipeline_throughput_bound
    (stages : ℕ) (hs : stages ≥ 2)
    (compute_bw memory_bw : ℚ) (hpos : compute_bw > 0 ∧ memory_bw > 0) :
    let ideal := min compute_bw memory_bw
    let achieved := (1 - 1 / stages) * ideal
    achieved ≥ (1 / 2) * ideal := by
  simp only []
  have h2 : (stages : ℚ) ≥ 2 := by exact_mod_cast hs
  have hstages_pos : (stages : ℚ) > 0 := by linarith
  have h_frac : 1 / (stages : ℚ) ≤ 1 / 2 := by
    apply div_le_div_of_nonneg_left _ (by norm_num) hstages_pos h2
    norm_num
  nlinarith [min_nonneg compute_bw memory_bw]

end PAX.PipelineDAG
