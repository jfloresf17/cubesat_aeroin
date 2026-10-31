# Planet ephemerides downloader

The repository also includes an independent Planet ephemerides downloader.
This guide describes that utility; the root [README](../README.md) documents
the PlanetScope consistency study.

## MATLAB and credentials for the downloader

- Use **MATLAB R2022b or newer**, with the JVM enabled. No Aerospace Toolbox
  is required. MATLAB executes the `.m` scripts and functions in this repository.
- Your local MATLAB installation needs a valid MathWorks license, configured
  through your normal MATLAB sign-in or institutional licensing setup.
- **The downloader needs no Planet account, API key, password, or `.env` file.**
  It makes unauthenticated HTTPS requests to
  <https://ephemerides.planet-labs.com/>. The code does not load `.env` files.
- Online downloads need internet access and a writable output directory.
  Offline runs need the cached source files instead.

The existing [GitHub Actions workflow](../.github/workflows/matlab.yml) installs
MATLAB R2022b and runs the tests. Public repositories receive automatic
licensing for the products used here. Private repositories require a MATLAB
batch licensing token stored as a GitHub Actions secret and mapped in the
workflow, for example:

```yaml
env:
  MLM_LICENSE_TOKEN: ${{ secrets.MLM_LICENSE_TOKEN }}
```

This is a MATLAB licensing token, separate from downloading Planet data.
See the [official MATLAB Actions licensing instructions](https://github.com/matlab-actions/setup-matlab#licensing)
for token requirements. The current workflow does not set this variable.

## Run the downloader

The root `main.m` starts the PlanetScope consistency study. To use the
independent downloader instead, call `downloadPlanetEphemerides` directly
from the repository root as shown below. It does not require a Planet API key.

The optional `examples/download_planet_ephemerides.m` script defaults to
offline mode and requires a previously populated cache. Set its `offline`
configuration to `false` before requesting new data.

## Download from Planet

You can also call the function directly from the repository root in MATLAB:

```matlab
addpath('utilities');

archive = downloadPlanetEphemerides("2026-09-01", "2026-09-03", ...
    'Flock', "4q", 'ID', ["24bd", "24d1"], ...
    'CacheOnly', false, 'Strict', true);

disp(archive.Summary);
disp(archive.Manifest);
disp(archive.RunDirectory);
```

Both dates are inclusive **UTC archive dates**, rather than bounds on the
orbital epochs inside the files. Future archive dates are rejected.

For each day, the downloader requests `planet_mc_YYYYMMDD.tle` and
`planet_YYYYMMDD.states`. It also retrieves the source index and
`18SPCS_matches_v1.txt` identity catalog. Daily files are shared across all
selected satellites: filtering happens after retrieval.

## Select records and control downloads

| Option | Default | Meaning |
| --- | --- | --- |
| `Flock` | `"all"` | One flock, such as `"4q"`, or several, such as `["4q","4be"]`. |
| `ID` | All IDs | One or more Planet hardware IDs. |
| `IDType` | `"hwid"` | Use `"catid"` to select catalog/NORAD IDs instead. |
| `OutputDirectory` | `data/planet_ephemerides` under the repository | Raw cache and generated outputs. |
| `UseCache` | `true` | Reuse existing daily files; verify hashes and URLs when receipts exist. Set `false` to refresh daily files online. |
| `CacheOnly` | `false` | Set `true` to prohibit HTTP requests, including metadata requests. |
| `MetadataDirectory` | Automatically chosen | Reuse a folder containing `index.html` and `18SPCS_matches_v1.txt` for a fixed metadata snapshot. |
| `Strict` | `false` | Set `true` to raise an error after saving an incomplete archive. Otherwise, emit a warning. |
| `Timeout` | `30` | Timeout in seconds per connection, response, or data interval. |
| `MaxAttempts` | `3` | Maximum attempts for transient HTTP or network failures. |
| `RetryPause` | `1` | Initial retry delay in seconds, with exponential backoff and server retry guidance. |
| `RequestPause` | `0.1` | Pause in seconds between noncached daily requests. |
| `Verbose` | `true` | Print download progress. |

Flock and ID filters are combined with AND; values within each filter are
combined with OR. Omit `ID` to select a whole flock. Catalog ID mapping uses
the same-day TLE first, then a flagged catalog-snapshot fallback.

`UseCache=true` can still fetch a new metadata snapshot during an online run.
Use `CacheOnly=true` for a fully offline run. Without an explicit
`MetadataDirectory`, offline mode uses the latest named cached metadata folder.

## Saved files

By default, files are written beneath `data/planet_ephemerides/`:

```text
raw/
  daily/YYYY/MM/            Original daily .tle and .states files
  metadata/<snapshot>/     Source index and identity catalog
runs/<run-id>/
  archive.mat              MATLAB variable named archive
  tle.csv, states.csv      Selected orbital records
  catalog.csv              Full identity catalog snapshot
  groups.csv               Per-satellite output locations and counts
  availability.csv         Per-satellite, per-day product availability
  manifest.csv             Source URLs, statuses, hashes, and cache details
  config.json              Run configuration
  sources/                 Copies of source metadata
  by_flock/<flock>/<hwid>/  Selected CSVs, records.tle, and records.states
```

Downloaded raw files have `.receipt.json` sidecars recording provenance and
SHA-256 hashes. Changed daily files from a forced refresh preserve their
previous bytes and receipts under `.versions/`. Each invocation creates a new
run directory, even when all source files come from cache.

Load a saved result in MATLAB with:

```matlab
saved = load(fullfile(archive.RunDirectory, 'archive.mat'));
tle = saved.archive.TLE;
states = saved.archive.States;
```

The downloader preserves native orbital epochs and source records. It does
not propagate or transform states. Planet data is distributed under
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).
Local data files and generated outputs are excluded from Git.

## Test the downloader

From the repository root in MATLAB:

```matlab
addpath('utilities');
results = runtests('tests');
assertSuccess(results);
```

The suite exercises parsing and offline caching with small, artificial test
records, and is the same suite run by CI. Tests requiring the optional
September 2026 Planet archives, catalogue snapshot and independent reference
CSV are separate from default CI. Run them explicitly when those files are
available:

```matlab
addpath('utilities');
realResults = runtests('tests_optional');
```

Missing optional fixtures are reported as incomplete rather than passed. See
[validation](VALIDATION.md) for the expected paths. The separate
PlanetScope consistency study has its own test command in the [root README](../README.md).
