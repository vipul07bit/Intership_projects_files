# Benchmark protocol and result capture

## Environments
| | Environment A (my own instance) | Environment B (reproduction) |
|---|---|---|
| Evidence | Four supplied execution plans | `sql/08_run_benchmarks.py` |
| Runs | One run; node actual time | 1 discarded warm-up + 5 recorded; median of `Execution Time` |
| PostgreSQL | Not stated | 16.15 on Ubuntu 24.04, 2 vCPU, 8 GB RAM |
| Settings | Probably `enable_seqscan = off` (inferred from cost 1e10) | Defaults: shared_buffers 128MB, work_mem 4MB, max_parallel_workers_per_gather 2; `jit = off` |
| Date | – | 2 November 2026 |

Times from different environments are never compared with each other.

## Procedure
1. Load the same synthetic dataset (`01`, `02`); confirm the counts 500 / 50,000 / 10,000 / 200,000 / 600,000 / 10,000.
2. `VACUUM (ANALYZE)` before baseline tests; confirm `SHOW enable_seqscan;` is `on`.
3. Run each baseline query once (discarded warm-up), then five recorded times with identical parameters.
4. Save `EXPLAIN (ANALYZE, BUFFERS)` text; record Execution Time, scan nodes, actual rows, shared hit/read blocks.
5. Create only the planned indexes (`05`), run `VACUUM (ANALYZE)` on the affected tables, repeat step 3.
6. For partitioning, compare against plain `orders` both with only the `05` indexes (BM-09) and with a matching `order_date` index (BM-10).
7. Report the **median**, never the best run. Compare a SHA of the full result set for each pair to prove identical results.

## Calculations
Improvement (%) = ((Before median ms − After median ms) / Before median ms) × 100. Positive = faster, negative = slower. If either value is missing the percentage is not calculated and the cell says "Not measured".

## Interpretation cautions
- Planner **cost** is in abstract units, not milliseconds; compare plans by cost only to understand the planner's choice.
- A cost starting with `10000000000` means a node type was disabled (e.g. `enable_seqscan = off`). Do not use that setting to "prove" an optimization.
- Sequential scans can be optimal when a large share of rows is needed; an index is not automatically faster.
- Warm-cache and cold-cache results are not mixed. All Environment B runs are warm (0 shared read blocks).
- Differences of a few microseconds (BM-08) are below reliable timer resolution.
- Indexes consume disk (here 23.2 MB for the two orders indexes against a 14.8 MB table) and add write cost; write overhead was not measured.
- Never report sample or expected timings as measured results.
