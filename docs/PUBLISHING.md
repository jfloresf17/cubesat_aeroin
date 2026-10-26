# Integration and publication

This package extends the public `jfloresf17/cubesat_aeroin` repository from
commit `afd41e59ed4ce55e667e7be95d42344c6e6e156e`. It adds the ingestion utility,
research entry point, examples, tests, documentation, and a small attributed
Planet dataset. Existing MIT licensing is retained for code.

1. Copy the package's `cubesat_aeroin/` contents into your repository checkout,
   including `.github/` and `.gitignore`. Alternatively, apply the supplied
   top-level patch from the repository root using `git apply`.
2. Run the checks below in MATLAB R2022b or newer.
3. Review the generated data inventory and `docs/VALIDATION.md`, update the
   validation record with the actual MATLAB results, and commit the changes.
4. Push your reviewed branch and inspect the MATLAB Actions result before
   tagging a release. Keep large/full-study datasets outside ordinary Git
   history; the included `.gitignore` already excludes generated runs.

```matlab
addpath('utilities');
results = runtests('tests');
assertSuccess(results);
main
```

To obtain new data, set `study.offline=false` in `main.m` and change its flock,
HWIDs and date range. Omit `ID` from the utility call to select a complete
flock. The example works without an API key.

The source-data notice in `data/LICENSE-Planet.txt` applies independently of
the MIT code license. If you distribute the included Planet fixture or any
derived subset, retain that attribution and its CC BY-NC 4.0 terms.
