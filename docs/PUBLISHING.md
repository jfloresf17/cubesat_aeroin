# Publication checks

The repository contains the root MATLAB ephemerides downloader and the
separate [PlanetScope consistency study](../planet_product_consistency/README.md).
Their prerequisites and test commands differ; see the respective READMEs.

Before publishing changes:

1. Review `git status` and the exact staged files. Keep `.env` files, downloaded
   archives, catalogue snapshots, image previews and generated runs out of Git.
2. Run the root downloader checks from the repository root in MATLAB R2022b or
   newer. The default suite uses artificial fixtures and fails on any failure
   or incomplete test. The separate `tests_optional` suite requires archived
   Planet inputs and is not included in default CI.
3. Run the consistency module's tests under its own documented requirements.
4. Review data attribution and source terms before sharing any derived data.
   The [Planet ephemerides notice](../data/LICENSE-Planet.txt) is separate from
   the MIT code licence. Downloaded Planet archives are not bundled.
5. Push the reviewed branch and inspect GitHub Actions before treating the CI
   result as release evidence.

```matlab
addpath('utilities');
results = runtests('tests');
assertSuccess(results);
```

The public ephemerides downloader does not need a Planet API key. A fresh
PlanetScope scene-catalogue search in the consistency module does require one;
credentials must remain local and must not be written into output files.
