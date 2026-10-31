# Data model and units

This dictionary describes the active MATLAB workflow. Follow the
[analysis guide](ANALYSIS_GUIDE.md) to inspect these tables and stage snapshots.

## MATLAB execution ledger

`ctx.stageLog` and `stage_log.csv` contain one row per configured stage:
`Stage` (00-07, or 00-03 for audit), `Name`, `Status`, `Elapsed_s`, `Checkpoint`
and `Message`. Status is `PENDING`, `RUNNING`, `COMPLETE` or `FAILED`.
`Checkpoint` identifies the stage MAT file; a failed save can leave a named
checkpoint absent, so check both status and file existence. `Message` retains
the exception identifier and message for a failed stage.

Each `stage_NN.mat` stores `snapshot`, including the ledger as it stood after
that stage. In a successful complete run, `results.mat` stores `results` with
the finalized ledger. `failed_context.mat` stores `failedContext` after a stage
error. These MAT files preserve the MATLAB types used in the analysis.

Publication of the stable latest report occurs after the stage snapshots and
`results.mat` are written, so their `latestReportStatus` can be `PENDING`.
The returned `ctx` and, when written, the run's `publication_status.mat` provide
the final `PUBLISHED` or `FAILED` status and path. On publication failure the completed
run's own `RUN_REPORT.md` remains the fallback; details are also recorded in
`REPORT_PUBLISH_FAILED.txt` when that diagnostic can be written.

## Native records

- `RecordID`: SHA-256 of canonical source payload. Original text is retained.
- `HWID`: four-character lower-case hex string; leading zeros preserved.
- `CatalogID`: catalogue identity as normalized decimal string, not HWID.
- `EpochTTns`: int64 nanoseconds relative to 2000-01-01 12:00:00 TT.
- `EpochUTC`: timezone-aware datetime for MATLAB evaluation and display.
- `EpochToken`: original serialized time; useful for source-precision review.
- `Rx_m ... Vz_mps`: position and velocity, source J2000-labelled axes.
- `BD_kg_m2`, `BSRP_kg_m2`: retained source metadata, never SGP4 overrides.
- `Line1`, `Line2`, `Name`: original TLE fields; no orbital-parameter modification.
- `ArchiveDateUTC`, `SourcePath`, `SourceSHA256`, `Line`: auditable provenance.
- `Revision`, `DuplicateOccurrences`, `Status`: preprocessing decisions.

## Pair records

A `PairID` hashes StateID + TLEID independently of sample label. It is the atomic
comparison record, not a satellite track or a generated minute-by-minute series.
`DeltaTime_ns = StateEpochTTns − TLEEpochTTns`; positive means forward evaluation.
`SelectedDaily` follows the latest-eligible-state rule. The 24-hour sensitivity never
fills missing primary matches. `IdentityVerified` persists into metrics.

## Evaluations and residuals

All evaluated inertial vectors use SI units. `RxT_m ...` and `RxC_m ...` retain both
prepared states. No claim of accuracy is encoded by the C label.
`Position_m`, `Velocity_mps` are 3D norms, not differences of radius or speed alone.
`Radial_m`, `Transverse_m`, `Normal_m` are signed POSITION components; no rotating-
frame velocity derivative is calculated. `Ground_m` is an ellipsoidal surface length.
`LatC_deg`, `LonC_deg`, `LatT_deg`, `LonT_deg` give the simultaneous WGS84
ellipsoid-normal Cartesian and TLE footpoints. `GroundEast_m` and `GroundNorth_m`
are signed geodesic distance-and-bearing components at the Cartesian footpoint,
positive east/north towards the TLE footpoint; `GroundAzimuth_deg` is the initial
azimuth clockwise from north. `hypot(GroundEast_m, GroundNorth_m) = Ground_m`.
At coincident footpoints both components are zero and azimuth is NaN because the
direction is undefined. These geographic components are not orbital RTN components.
`Status=FAILED` preserves error identifiers/messages and excludes the record from
joint statistics. It never sets discrepancy to zero.

CSV files serialize int64 epochs as decimal strings; read them as strings or int64,
not spreadsheet floating-point numbers. MAT files retain their original types.

## Summary estimands

`N` counts successful pairs. RMS is sqrt(mean(vector squared distance)). A component
SD uses N−1 and requires N>1. `DistinctDates` and `Satellites` expose support. Missing
satellites/months retain N=0 and NaN metrics. Component RMS and vector RMS refer to the
same pairs. Bootstrap intervals apply to the statistic named in `Metric` and are
not per-state prediction intervals or covariances.

`table6_ground_en_pooled.csv` reports signed mean, sample SD and RMS for the
successful primary sample. `table6_ground_en_all_groups.csv` retains sample,
group and weighting labels for primary, separately selected sensitivity and
other descriptive groups. Equal-satellite rows report RMS only; their means and
SDs are NaN. Each row uses the same successful pairs as its corresponding scalar
ground and RTN summary. `summary_all.csv` also keeps the 24-hour and
asynchronous-only samples separate.
Pooled component means can cancel geographically; use the plots and
satellite/month summaries when interpreting directional structure.

`ground_daily_summary.csv` has `DateUTC`, `N`, `RMS_m`, `Median_m`, `Q95_m`,
and `Max_m` for dates with successful primary pairs. `ground_satellite_summary.csv`
uses the same statistics for each roster satellite and includes `DistinctDates`;
satellites with N=0 retain unavailable metrics. Daily RMS aggregates the pairs
present on that date, not all times along an orbit. For N=1 it equals that one
pair's ground distance. The coordinate plot labels its selected satellite and
shows its discrete pair dates rather than an interpolated track.
