# Downloader validation

The default root downloader tests contain deterministic parser, UTC conversion,
checksum, transport, cache-integrity and offline-integration checks. Small
artificial records are constructed in temporary directories; they are not
Planet observations. Run the same command as CI from the repository root in
MATLAB:

```matlab
addpath('utilities');
results = runtests('tests');
assertSuccess(results);
```

Ten additional tests use previously acquired 1–3 September 2026 Planet
archives, a matching-report snapshot and an independent availability CSV.
Those files are not distributed with this repository and are ignored by Git.
The optional tests are not part of default CI. To run them explicitly:

```matlab
addpath('utilities');
realResults = runtests('tests_optional');
```

The optional suite expects daily files under
`data/planet_ephemerides/raw/daily/2026/09/`, source metadata under
`data/planet_ephemerides/raw/metadata/20261025_source/`, and the independent
reference at `data/reference/availability.csv`. Missing fixtures produce
assumption-based incomplete results; a missing fixture is not a pass. Inspect
`realResults` before interpreting its outcome.

The test suite checks the downloader implementation and does not validate orbit
accuracy or the separate PlanetScope consistency module. The latter has its
own instructions and test command in its [README](../planet_product_consistency/README.md).

An earlier independent audit used Planet source files and reference values
from September 2026, but those files are not included in this release. The
historical `tools/audit_bundled_data.py` requires those separately obtained
local files and is not part of the default CI test run. Planet-derived data
remain subject to their source licence.
