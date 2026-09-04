# Contributing to CGeV

Thank you for helping improve CGeV. Use GitHub Issues for reproducible bug
reports, enhancement proposals, and questions about the source code.

## Development workflow

1. Create a focused branch from `master`.
2. Keep generated data, local configuration, credentials, caches, and
   installers out of commits.
3. Add or update tests for behavior changes.
4. Run the relevant checks before opening a pull request:

```bash
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
node tests/js/test_plot_paint_gate.js
npm --prefix desktop test
npm --prefix desktop run verify:config
```

For changes that need the full application runtime, follow the Docker setup in
the main README. Describe the tested platform, dataset, and commands in the
pull request.

## Scientific changes

Changes affecting identifier resolution, genomic coordinates, sequence
extraction, alignment, or exported results should document the reference
assembly, annotation release, inputs, expected result, and software version.

By submitting a contribution, you agree that it may be distributed under the
repository's MIT License.
