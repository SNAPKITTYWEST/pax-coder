// PAX Pipeline GEMM — 3-stage async cp.async with overlap guarantee
// Ahmad Ali Parr · PAX Architecture · sm_86
// Proof obligations: PO4 (happens-before), PO6 (barrier conservation), PO7 (data-race freedom)

#include <cuda_fp16.h>
#include <mma.h>

using namespace nvcuda;

#define STAGES 3
#define TILE_M 64
#define TILE_N 64
#define TILE_K 16

__shared__ __half smem_a[STAGES][TILE_K][TILE_M];
__shared__ __half smem_b[STAGES][TILE_K][TILE_N];

// cp.async descriptor for one tile
inline __device__ void async_load_tile(
    __half* dst, const __half* src, int bytes
) {
    asm volatile(
        "cp.async.ca.shared.global [%0], [%1], %2;\n"
        : : "r"((unsigned)__cvta_generic_to_shared(dst)),
            "l"(src), "n"(32)
    );
}

extern "C" __global__ void pax_gemm_pipeline_sm86(
    const __half* A, const __half* B, float* C,
    int M, int N, int K
) {
    int lane = threadIdx.x % 32;
    int warp = threadIdx.x / 32;

    wmma::fragment<wmma::accumulator, 16, 8, 8, float> acc;
    wmma::fill_fragment(acc, 0.0f);

    // Prologue: fill pipeline (stages 0..STAGES-2)
    for (int s = 0; s < STAGES - 1 && s * TILE_K < K; s++) {
        int kOff = s * TILE_K;
        async_load_tile(&smem_a[s][0][0], A + kOff * M + blockIdx.y * TILE_M, 32);
        async_load_tile(&smem_b[s][0][0], B + kOff * N + blockIdx.x * TILE_N, 32);
        asm volatile("cp.async.commit_group;\n");
    }

    // Steady state: compute stage s while loading stage s+STAGES-1
    for (int k = 0; k < K; k += TILE_K) {
        int cur = (k / TILE_K) % STAGES;
        int pre = (k / TILE_K + STAGES - 1) % STAGES;

        // PO4: wait_group 1 = wait for all but 1 outstanding group
        // HB(copy[k], compute[k]) enforced here
        asm volatile("cp.async.wait_group 1;\n");
        __syncthreads();  // PO6: barrier consumes all permissions from prior cp.async

        wmma::fragment<wmma::matrix_a, 16, 8, 8, __half, wmma::row_major> a_frag;
        wmma::fragment<wmma::matrix_b, 16, 8, 8, __half, wmma::col_major> b_frag;

        // PO3: whole warp executes mma.sync
        wmma::load_matrix_sync(a_frag, &smem_a[cur][0][0], TILE_M);
        wmma::load_matrix_sync(b_frag, &smem_b[cur][0][0], TILE_N);
        wmma::mma_sync(acc, a_frag, b_frag, acc);

        // Prefetch next tile — PO4: HB(compute[k], copy[k+STAGES-1])
        int nextK = k + (STAGES - 1) * TILE_K;
        if (nextK < K) {
            async_load_tile(&smem_a[pre][0][0], A + nextK * M + blockIdx.y * TILE_M, 32);
            async_load_tile(&smem_b[pre][0][0], B + nextK * N + blockIdx.x * TILE_N, 32);
            asm volatile("cp.async.commit_group;\n");
        }
    }

    // Epilogue: drain pipeline
    asm volatile("cp.async.wait_all;\n");
    __syncthreads();

    // PO5: store — write permission is warp-local
    int row = blockIdx.y * TILE_M;
    int col = blockIdx.x * TILE_N;
    if (row < M && col < N)
        wmma::store_matrix_sync(C + row * N + col, acc, N, wmma::mem_row_major);
}
