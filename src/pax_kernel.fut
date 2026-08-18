-- PAX Futhark GEMM — functional specification for PAX PTX kernels
-- Ahmad Ali Parr · PAX Architecture
-- Functional correctness spec: pax_gemm_spec A B C == pax_gemm_impl A B C

-- Matrix-matrix multiply: C = A × B + C₀
-- A: [m][k]f16, B: [k][n]f16, C₀: [m][n]f32
def gemm_fp16_f32 [m] [n] [k]
    (A : [m][k]f16) (B : [k][n]f16) (C0 : [m][n]f32) : [m][n]f32 =
  map2 (map2 (+)) C0
    (map (\i ->
       map (\j ->
         f32.sum (map2 (\a b -> f16.to_f32 a * f16.to_f32 b)
                       A[i] (map (\brow -> brow[j]) B)))
       (iota n))
    (iota m))

-- Bias+GeLU epilogue functional spec
def gelu_approx (x : f32) : f32 =
  let sqrt_2_pi : f32 = 0.7978845608f32
  let coef : f32 = 0.044715f32
  let inner = sqrt_2_pi * (x + coef * x * x * x)
  in 0.5f32 * x * (1.0f32 + f32.tanh inner)

def bias_gelu [m] [n] (C : [m][n]f32) (bias : [n]f32) : [m][n]f32 =
  map (map2 (\c b -> gelu_approx (c + b)) bias) C

-- Three-stage pipeline model:
-- compute and memory ops interleaved in STAGES phases
def pipeline_gemm [m] [n] [k]
    (A : [m][k]f16) (B : [k][n]f16) (stages : i64) : [m][n]f32 =
  let tile_k = k / stages
  in loop (acc : [m][n]f32) = replicate m (replicate n 0.0f32)
     for s in iota stages do
       let k_start = s * tile_k
       let A_tile = map (\row -> A[row, k_start : k_start + tile_k]) (iota m)
       let B_tile = map (\row -> B[row, :]) (iota tile_k)
       in map2 (map2 (+)) acc (gemm_fp16_f32 A_tile B_tile (replicate m (replicate n 0.0f32)))

-- Entry point: full GEMM + bias + GeLU
entry pax_gemm_bias_gelu [m] [n] [k]
    (A : [m][k]f16) (B : [k][n]f16) (bias : [n]f32) : [m][n]f32 =
  let C = gemm_fp16_f32 A B (replicate m (replicate n 0.0f32))
  in bias_gelu C bias
