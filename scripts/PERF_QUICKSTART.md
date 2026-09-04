# Performance Quickstart

Default startup values for the eager rendering profile:

- `APP_FUTURE_MODE=multisession`
- `APP_FUTURE_WORKERS=2`
- `APP_HOMO_INITIAL_VISIBLE=64`
- `APP_ORTHO_INITIAL_VISIBLE=64`
- `APP_ORTHO_RENDER_CHUNK_SIZE=64`
- `APP_ORTHO_AUTO_RENDER_MORE=0`
- `APP_ORTHO_AUTO_RENDER_DELAY_MS=0`
- `APP_HOMO_UPFRONT_ISOFORMS=0`
- `APP_ORTHO_UPFRONT_ISOFORMS=0`
- `APP_ORTHO_SUSPEND_HIDDEN=1`
- `APP_HOMO_DEFER_SEQUENCE=0`
- `APP_ORTHO_DEFER_SEQUENCE=0`
- `APP_FOOTER_DEFER_SEQUENCE=0`
- `APP_DEFER_FEATURE_GC=0`
- `APP_ORTHO_ALIGNED_FAST=1`

These defaults register all normal primary cards together and include sequence
composition and feature GC in their first render. Hidden isoforms are still
created only when expanded, and hidden Alignment outputs remain suspended.

Colors deploys materialize the same eager baseline by default:

- `APP_INLINE_FAST_SEQUENCE_PREFETCH=1`
- `APP_HOMO_DEFER_SEQUENCE=0`
- `APP_ORTHO_DEFER_SEQUENCE=0`
- `APP_FOOTER_DEFER_SEQUENCE=0`
- `APP_DEFER_FEATURE_GC=0`
- `APP_ORTHO_AUTO_RENDER_MORE=0`
- `APP_ORTHO_RENDER_CHUNK_SIZE=64`
- `APP_HOMO_INITIAL_VISIBLE=64`
- `APP_ORTHO_INITIAL_VISIBLE=64`

The deferred `0/1/1` candidate was rejected after production measurements:
it moved cold work into a second render and made warm searches slower.

The deploy-time defaults can still be overridden explicitly for a controlled
comparison, but normal deploys always write and verify the eager profile.

## Recommended: run the suite wrapper

This orchestrates optional cache cleanup, prewarm, the general perf suite, the aligned suite, and copies the testing guides into one output directory.

```bash
bash /path/to/CGeV/scripts/run_benchmark_suite.sh --trials 3 --prewarm
```

For a colder comparison:

```bash
bash /path/to/CGeV/scripts/run_benchmark_suite.sh --trials 3 --cold-cache --prewarm
```

## Single run (cache ON)

```bash
bash /path/to/CGeV/scripts/run_app_perf.sh on /tmp/fullapp_perf_on.log TRUE
```

To force a concurrency comparison:

```bash
APP_FUTURE_MODE=sequential APP_FUTURE_WORKERS=2 bash /path/to/CGeV/scripts/run_app_perf.sh on /tmp/fullapp_perf_seq.log TRUE
APP_FUTURE_MODE=multisession APP_FUTURE_WORKERS=2 bash /path/to/CGeV/scripts/run_app_perf.sh on /tmp/fullapp_perf_multi.log TRUE
```

## Single run (cache OFF)

```bash
bash /path/to/CGeV/scripts/run_app_perf.sh off /tmp/fullapp_perf_off.log TRUE
```

## Compare ON vs OFF

```bash
Rscript /path/to/CGeV/scripts/compare_perf_logs.R /tmp/fullapp_perf_on.log /tmp/fullapp_perf_off.log
```

## 3x benchmark

```bash
bash /path/to/CGeV/scripts/run_perf_benchmark_3x.sh 3
```

## Aligned-only 3x benchmark (ORTHO fast ON vs OFF)

```bash
bash /path/to/CGeV/scripts/run_aligned_benchmark_3x.sh 3
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
Rscript /path/to/CGeV/scripts/summarize_aligned_perf_log.R /tmp/fullapp_aligned_debug.log
```
