# Benchmark Protocol

Use the same flow in every run. The goal is consistency, not exploration.

## General rules

- Use the same machine and avoid heavy background jobs.
- Close other browser tabs if possible.
- Do not change theme, colorblind mode, or hidden app settings mid-run.
- In every benchmark run, follow the same click order.
- When the app reaches the target state and PERF logs are printed, stop the run with `Ctrl+C`.

## Homologous flow

1. Open the app.
2. Go to `Homologous`.
3. Select the same organism every time.
4. Search the same gene every time.
5. Wait until the first plot is visible.
6. Wait until all expected plots are ready.
7. Open Summary.
8. Open Analytics.
9. Stop the run with `Ctrl+C`.

Recommended: use a stable, common gene with known results in your preferred organism.

## Orthologous flow

1. Open the app.
2. Go to `Orthologous`.
3. Select the same organism set every time.
4. Search the same gene every time.
5. Wait until the first ortholog plot is visible.
6. Wait until all visible plots are ready.
7. Open Summary.
8. Open Analytics.
9. Stop the run with `Ctrl+C`.

## Aligned flow

Use this only for the aligned benchmark.

1. Open the app.
2. Go to `Orthologous`.
3. Select the same organism set every time.
4. Search the same gene every time.
5. Switch to `Comparative Aligned`.
6. Wait until the aligned plot is fully visible.
7. Change one aligned control with the same pattern every run:
   - reorder tracks, or
   - toggle representative mode, or
   - change minimum identity.
8. Wait until the rerender finishes.
9. Stop the run with `Ctrl+C`.

## Cold vs warm

- `Cold`: clear cache first, then run without prior prewarm.
- `Warm`: prewarm first, then run the same flow.

## What to compare

- first plot ready time
- total plots ready time
- aligned total time
- aligned collect time
- aligned plot build time
- cache hit vs cache miss

## Recommended command sequence

Cold + prewarm + full suite:

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_benchmark_suite.sh --trials 3 --cold-cache --prewarm
```

Warm + full suite:

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_benchmark_suite.sh --trials 3 --prewarm
```

Aligned only:

```bash
bash /Users/rarojas/Documents/A_FULLAPP/scripts/run_benchmark_suite.sh --trials 3 --aligned-only --prewarm
```
