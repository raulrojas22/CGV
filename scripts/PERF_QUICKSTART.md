# Performance Quickstart

Default startup values for first paint tuning:

- `APP_FUTURE_MODE=multisession`
- `APP_FUTURE_WORKERS=2`
- `APP_HOMO_INITIAL_VISIBLE=1`
- `APP_ORTHO_INITIAL_VISIBLE=1`
- `APP_HOMO_UPFRONT_ISOFORMS=0`
- `APP_ORTHO_UPFRONT_ISOFORMS=0`
- `APP_ORTHO_SUSPEND_HIDDEN=1`
- `APP_HOMO_DEFER_SEQUENCE=1` for Desktop first paint; use `0` when sequence composition must be ready before paint
- `APP_ORTHO_DEFER_SEQUENCE=1` for Desktop first paint; use `0` when sequence composition must be ready before paint
- `APP_FOOTER_DEFER_SEQUENCE=1` for Desktop first paint; use `0` when footer sequences must be ready before paint
- `APP_DEFER_FEATURE_GC=1` for Desktop; small 2bit spans are included in the first render, while slower sources retain the deferred fallback
- `APP_ORTHO_ALIGNED_FAST=1`

These defaults prioritize first paint. Hidden isoforms are not instantiated
upfront, hidden orthologous plots stay suspended, and expensive sequence/feature
GC work is deferred and prefetched after the initial card renders.

## Recommended: run the suite wrapper

This orchestrates optional cache cleanup, prewarm, the general perf suite, the aligned suite, and copies the testing guides into one output directory.

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_benchmark_suite.sh --trials 3 --prewarm
```

For a colder comparison:

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_benchmark_suite.sh --trials 3 --cold-cache --prewarm
```

## Single run (cache ON)

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_app_perf.sh on /tmp/fullapp_perf_on.log TRUE
```

To force a concurrency comparison:

```bash
APP_FUTURE_MODE=sequential APP_FUTURE_WORKERS=2 bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_app_perf.sh on /tmp/fullapp_perf_seq.log TRUE
APP_FUTURE_MODE=multisession APP_FUTURE_WORKERS=2 bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_app_perf.sh on /tmp/fullapp_perf_multi.log TRUE
```

## Single run (cache OFF)

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_app_perf.sh off /tmp/fullapp_perf_off.log TRUE
```

## Compare ON vs OFF

```bash
Rscript /Users/rarojas/Documents/A_FULLAPP/scripts/compare_perf_logs.R /tmp/fullapp_perf_on.log /tmp/fullapp_perf_off.log
```

## 3x benchmark

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_perf_benchmark_3x.sh 3
```

## Aligned-only 3x benchmark (ORTHO fast ON vs OFF)

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_aligned_benchmark_3x.sh 3
```

This compares:

- `APP_ORTHO_ALIGNED_FAST=1` (ON)
- `APP_ORTHO_ALIGNED_FAST=0` (OFF / legacy path)

and prints median ON vs OFF deltas for:

- `aligned_total_ms_median`
- `aligned_collect_ms_median`
- `aligned_plot_build_ms_median`
- `ortho_first_plot_ms_median`
- `ortho_total_ready_ms_median`

## Summarize one aligned log

```bash
Rscript /Users/rarojas/Documents/A_FULLAPP/scripts/summarize_aligned_perf_log.R /tmp/fullapp_aligned_debug.log
```
