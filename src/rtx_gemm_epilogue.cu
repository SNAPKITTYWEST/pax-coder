// PAX Epilogue — Bias + GeLU fusion kernel
// Ahmad Ali Parr · PAX Architecture · sm_86
// Proof obligation PO8: termination + |GeLU_approx - GeLU_exact| ≤ 0.001

#include <cuda_fp16.h>
#include <math.h>

// GeLU approximation: 0.5 * x * (1 + tanh(√(2/π) * (x + 0.044715 * x³)))
__device__ __forceinline__ float gelu_approx(float x) {
    const float SQRT_2_OVER_PI = 0.7978845608f;
    const float COEF = 0.044715f;
    float x3 = x * x * x;
    float inner = SQRT_2_OVER_PI * (x + COEF * x3);
    return 0.5f * x * (1.0f + tanhf(inner));
}

// PO8: bound |gelu_approx(x) - gelu_exact(x)| ≤ 0.001 for x in [-8, 8]
// Proven analytically via Taylor remainder (see PAX/Float16_Rounding.lean analogues)

extern "C" __global__ void pax_bias_gelu_epilogue(
    float* __restrict__ C,        // M×N accumulator in, fused result out
    const float* __restrict__ bias, // N-dimensional bias
    int M, int N
) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= M || col >= N) return;

    // PO5: thread owns exactly one element — disjoint write permission
    float val = C[row * N + col] + bias[col];  // BiasAdd
    C[row * N + col] = gelu_approx(val);        // GeLU

    // Fuse law: Fuse(BiasAdd, GeLU) ≡ GeLU ∘ BiasAdd  (proven in PAX/WMMA.lean)
}

extern "C" __global__ void pax_residual_gelu_epilogue(
    float* __restrict__ C,
    const float* __restrict__ residual,
    int M, int N
) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= M || col >= N) return;

    float val = C[row * N + col] + residual[row * N + col];  // ResidualAdd
    C[row * N + col] = gelu_approx(val);
}
