# Validation status

Prepared for `jfloresf17/cubesat_aeroin` from main commit
`afd41e59ed4ce55e667e7be95d42344c6e6e156e` on 25 October 2026.

## Checks performed

| Check | Result |
| --- | --- |
| Public repository inspected | The supplied base contained README.md and an MIT license; the ingestion stage was added as a new module. |
| Planet source endpoint verification | Successfully retrieved the documented daily TLE and state URLs for 1, 2 and 3 September 2026, plus the source-page and matching-report snapshots. |
| Independent fixture audit | Passed: eight source-file hashes/byte counts, 294 TLE records, 294 states, 588 element-line checksums, catalog parsing, daily HWID correspondence, known UTC epoch and the two-HWID sample selection. |
| MATLAB static parser/linter | MISS_HIT analysed 13 MATLAB files without reported findings, using its MATLAB 2022a syntax mode (the tool's latest supported syntax version). The TT2000 API requires R2022b. |
| Offline reference outputs | Six TLE rows, six state rows and six paired satellite-days; grouped source subsets and CSVs are included in data/reference/. These were generated independently in Python. |
| MATLAB execution | **Not performed.** Neither MATLAB nor an equivalent licensed MATLAB runtime was available in the preparation environment. |

The MATLAB suite contains 21 offline tests, including integration tests that
compare native epoch separations against the independent reference CSV.
Mock transport tests cover HTTP 404, transient retries, rejected HTTP 200 error
bodies, cache tampering and preservation of refreshed versions.

The supplied GitHub Actions workflow is configured to execute the suite in
MATLAB R2022b. Its result is pending until the code is published and CI runs.
Before a software release, run the suite in MATLAB and review any platform or
version-specific findings. No successful MATLAB test run is claimed here.

## Reproduce checks

```matlab
addpath('utilities');
results = runtests('tests');
assertSuccess(results);
main
```

For the independent source-data audit:

```bash
python tools/audit_bundled_data.py
```

The Python reference converter is restricted to the bundled September 2026
dates. Its explicit TT-UTC offset is not used by the MATLAB implementation,
which uses leap-aware TT2000 conversion. Reference UTC strings are rounded to
microseconds; the MATLAB comparison tolerance is 3 microseconds.
