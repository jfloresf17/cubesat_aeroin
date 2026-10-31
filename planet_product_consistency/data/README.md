# Local data

The MATLAB workflow reads cached Planet ephemeris inputs and auxiliary
Earth-orientation data. See the [project README](../README.md) for setup and
the analysis commands. Downloaded files and credentials are not included in a
fresh checkout.

| Path | Purpose |
| --- | --- |
| `data/raw/` | Default location for compatible native `.states` and TLE archives. |
| `data/planet_ephemerides/raw/daily/` | Alternative dated archive cache, organized by year and month. |
| `data/planet_psscene/catalogue_2026.mat` | Optional local PSScene input snapshot; coverage is limited to the time windows originally searched. |
| `data/planet_psscene/raw/xml/` and `data/planet_psscene/raw/thumbnails/` | Locally preserved, downloaded Planet metadata and image previews. |
| `data/auxiliary/` | Cached USNO/IERS Earth-orientation data and provenance. |
| `config/roster.csv` and `config/leap_seconds.csv` | Supplied identity candidates and time-scale inputs; review their validity before research use. |

The project may create folders as needed. Keep raw source files and their
receipts unchanged; input provenance and availability affect the analysis.
Downloaded data have their own [Planet data licence](LICENSE-Planet.txt).
These caches are ignored by Git and are not automatically present for others.
