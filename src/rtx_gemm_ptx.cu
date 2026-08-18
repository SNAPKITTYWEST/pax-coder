// PAX GEMM — sm_86 PTX kernel with mma.sync.aligned.m16n8k8 FP16→FP32
// Ahmad Ali Parr · PAX Architecture
// Proof obligations: PO1 (partition), PO3 (SIMT), PO5 (permissions), PO8 (verification)

#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>

using namespace nvcuda;

// Tile sizes: 128×128 work-group, 32×64 warp tile, 16×8 MMA tile
#define WGSIZE_M 128
#define WGSIZE_N 128
#define WGSIZE_K 32
#define WARP_M   32
#define WARP_N   64
#define MMA_M    16
#define MMA_N    8
#define MMA_K    8

// Shared memory: double-buffered A+B tiles
__shared__ __half smem_a[2][WGSIZE_K][WGSIZE_M];
__shared__ __half smem_b[2][WGSIZE_K][WGSIZE_N];

extern "C" __global__ void pax_gemm_sm86(
    const __half* __restrict__ A,     // M×K FP16
    const __half* __restrict__ B,     // K×N FP16
    float*        __restrict__ C,     // M×N FP32 accumulator
    int M, int N, int K
) {
    // PO1: Index space partition — each warp owns disjoint 32×64 tile
    int warp_id   = (threadIdx.x + threadIdx.y * blockDim.x) / 32;
    int warp_row  = warp_id / (WGSIZE_N / WARP_N);
    int warp_col  = warp_id % (WGSIZE_N / WARP_N);

    int block_row = blockIdx.y * WGSIZE_M + warp_row * WARP_M;
    int block_col = blockIdx.x * WGSIZE_N + warp_col * WARP_N;

    // FP32 accumulators — PO4: independent per warp, no sharing
    wmma::fragment<wmma::accumulator, MMA_M, MMA_N, MMA_K, float>
        c_frag[WARP_M / MMA_M][WARP_N / MMA_N];
    for (int i = 0; i < WARP_M / MMA_M; i++)
        for (int j = 0; j < WARP_N / MMA_N; j++)
            wmma::fill_fragment(c_frag[i][j], 0.0f);

    // Main K-loop: 3-stage cp.async double buffer
    int buf = 0;

    // Stage 0: prefetch first tile asynchronously
    asm volatile("cp.async.ca.shared.global [%0], [%1], 32;\n"
                 : : "r"((unsigned)__cvta_generic_to_shared(&smem_a[buf][0][0])),
                     "l"(A));
    asm volatile("cp.async.ca.shared.global [%0], [%1], 32;\n"
                 : : "r"((unsigned)__cvta_generic_to_shared(&smem_b[buf][0][0])),
                     "l"(B));
    asm volatile("cp.async.commit_group;\n");

    for (int k = 0; k < K; k += WGSIZE_K) {
        // Wait for previous async copy — PO4: HB(copy[s], compute[s])
        asm volatile("cp.async.wait_group 0;\n");
        __syncthreads();

        // Load A and B fragments from shared memory
        wmma::fragment<wmma::matrix_a, MMA_M, MMA_N, MMA_K, __half, wmma::row_major> a_frag;
        wmma::fragment<wmma::matrix_b, MMA_M, MMA_N, MMA_K, __half, wmma::col_major> b_frag;

        // PO3: all threads in warp execute mma.sync — no divergence
        for (int i = 0; i < WARP_M / MMA_M; i++) {
            wmma::load_matrix_sync(a_frag, &smem_a[buf][0][warp_row * WARP_M + i * MMA_M], WGSIZE_M);
            for (int j = 0; j < WARP_N / MMA_N; j++) {
                wmma::load_matrix_sync(b_frag, &smem_b[buf][0][warp_col * WARP_N + j * MMA_N], WGSIZE_N);
                // mma.sync.aligned.m16n8k8.f32.f16.f16.f32 — PO3: synchronized
                wmma::mma_sync(c_frag[i][j], a_frag, b_frag, c_frag[i][j]);
            }
        }

        buf ^= 1; // double buffer flip

        // Prefetch next tile — PO4: HB(compute[s], copy[s+1])
        if (k + WGSIZE_K < K) {
            asm volatile("cp.async.ca.shared.global [%0], [%1], 32;\n"
                         : : "r"((unsigned)__cvta_generic_to_shared(&smem_a[buf][0][0])),
                             "l"(A + (k + WGSIZE_K) * M));
            asm volatile("cp.async.ca.shared.global [%0], [%1], 32;\n"
                         : : "r"((unsigned)__cvta_generic_to_shared(&smem_b[buf][0][0])),
                             "l"(B + (k + WGSIZE_K) * N));
            asm volatile("cp.async.commit_group;\n");
        }
    }

    // Store accumulators to global memory — PO5: write permission owned by this warp
    for (int i = 0; i < WARP_M / MMA_M; i++) {
        for (int j = 0; j < WARP_N / MMA_N; j++) {
            int out_row = block_row + i * MMA_M;
            int out_col = block_col + j * MMA_N;
            if (out_row < M && out_col < N)
                wmma::store_matrix_sync(
                    C + out_row * N + out_col,
                    c_frag[i][j],
                    N,
                    wmma::mem_row_major
                );
        }
    }
}
