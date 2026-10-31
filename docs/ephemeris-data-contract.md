# Ephemeris ingestion data contract

## Product, date and epoch

The source URL templates are the ones published by Planet:

| Product | Daily historical URL suffix | Native time/frame/unit convention |
| --- | --- | --- |
| TLE | `planet_mc_YYYYMMDD.tle` | Native TLE epoch in UTC; retain complete mean-element records for SGP4. |
| Cartesian state | `planet_YYYYMMDD.states` | Seconds since 2000-01-01 12:00:00 TT; J2000 frame; position m; velocity m/s. |
| Matching report | `18SPCS_matches_v1.txt` | A retrieved supporting identity snapshot, with its own report epoch. |

`ArchiveDate` is the date in the requested filename. `RetrievedUTC` is when
bytes were obtained, or an empty string when no original receipt is available.
`EpochUTC` is the physical epoch of one orbital record. These are distinct.
Both TLE and state `EpochUTC` columns use `UTCLeapSeconds`, allowing elapsed
time subtraction without erasing leap seconds. Original epoch strings remain
available for source-precision reconstruction.

The state converter uses MATLAB's `datetime(...,'ConvertFrom','tt2000',
'TimeZone','UTCLeapSeconds')` after converting source TT seconds to nanoseconds.
It does not use UTC noon as J2000 or subtract a fixed TT-UTC offset. IEEE double
source parsing and nanosecond conversion can introduce sub-microsecond
rounding near the referenced epochs. `EpochTT_text` and the original bytes remain
authoritative. Keep MATLAB's leap-second information current for future data.

Planet describes Cartesian coordinates as "J2000" on its public page. This
does not by itself document every detail needed for an exact transformation
to an Earth-fixed frame. SGP4 conventionally outputs TEME. This ingestion
stage stores those conventions; subsequent research code must implement and
document its time/frame alignment before subtracting states.

## Identity and flock membership

1. A HWID in an archived TLE name takes priority. The name also supplies its
   archived flock. This supports historical flocks absent from a live catalog.
2. If a TLE has no name/HWID, an unambiguous official `catid` in the retrieved
   report can resolve it. `IdentitySource="catalog-snapshot"` makes that
   fallback explicit. Unresolved rows remain in the main TLE table.
3. A Cartesian row supplies its own HWID. Its flock and catalog label are
   attached using the same archive day's TLE HWID, then the report snapshot
   if no such label is available. These sources are retained per row.
4. The report's slash-separated candidate `matches`, RMS values and flags
   are retained as text. They are never treated as extra satellite aliases.
5. A conflicting snapshot catalog ID never replaces the one printed in a
   named TLE. `CatalogSnapshotConflict` records that conflict. CATID filters
   can return multiple HWIDs if source labels are ambiguous; HWID remains the
   preferred key for the research dataset.

The public report labels catalog matching as best guess and warns about
cross-tagging. A current report is not evidence of historical operational
status or an independently verified historical match. No historical record
is excluded because a current satellite is nonoperational. Explicit unknown
HWIDs requested without a flock are represented as empty groups; combinations
of a flock and an unknown ID cannot establish its historical membership.

`all` includes all published products (including SkySat IDs such as `s1`).
Supply a flock to select a PlanetScope cohort. Four-character hexadecimal
HWIDs, including leading zeros, remain strings. Group paths retain prime
suffixes; memberships that conflict across the requested interval use the
`mixed` group, while the row-level labels remain intact.

## Availability and native epoch separation

Every selected satellite/archive-date combination is represented, even when
one or both products have no row. `HasBoth` reports product presence, not
ephemeris accuracy or verified correspondence. `TLERow` and `StateRow` are
one-based row indices into the returned filtered tables when a unique row
exists; otherwise they are NaN.

When exactly one TLE and one state exist for an ID/date:

`NativeEpochSeparation_s = TLE.EpochUTC - States.EpochUTC`

This signed time difference is not a propagated-state error. No Cartesian
distance is computed by the downloader. Multiple records are retained, with
counts greater than one and NaN pairing indices/separation where ambiguous.
The chosen source comparison must be specified by the downstream experiment.

An archive cannot recover updates that Planet did not publish in the daily
files. No interpolation, latest-file substitution, or propagation fills a gap.

## Reproducibility boundaries

Daily source files and receipts are shared across runs. Each run has a unique
directory and records the hashes it consumed, preserving selection history.
For a frozen rerun, retain raw files/receipts and pass `CacheOnly=true` plus
the original `MetadataDirectory`. If refreshing a source changes its bytes,
the old version is saved in `.versions`; restoring a fully frozen dataset
requires pointing a separate output directory at the desired archived files.

The public service can change formats, remove files, or update mappings.
Unexpected source formats are reported as `invalid-content`, with the parser
error preserved in the run manifest. A partial retrieval is never labelled a
complete observation sample.

## Primary references

- Planet Labs PBC, [Public orbital ephemerides](https://ephemerides.planet-labs.com/).
- Planet Labs PBC, [18 SPCS matching report](https://ephemerides.planet-labs.com/18SPCS_matches_v1.txt).
- MathWorks, [datetime and TT2000](https://www.mathworks.com/help/matlab/ref/datetime.html).
- MathWorks, [HTTPOptions](https://www.mathworks.com/help/matlab/ref/matlab.net.http.httpoptions-class.html).
