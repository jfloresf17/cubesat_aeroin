# Full MATLAB study and research protocol

The [README](../README.md) and [analysis guide](ANALYSIS_GUIDE.md) provide the
MATLAB first-analysis workflow. This document retains the full six-month study settings,
scientific approval requirements and precision conventions.

For the complete audit (36 candidate identities, March-August 2026):

```matlab
startup_consistency
cfg = study_config("audit");
ctx = run_study(cfg);
```

For research evaluation, review the gates below before setting approved overrides:

```matlab
cfg = study_config("research");
% Supply reviewed identity intervals, frame policy and SGP4 evidence below.
ctx = run_study(cfg);
```

The MATLAB pipeline requires independent verification of its SGP4
implementation, frame interpretation and historical satellite identity.

## Full study settings implemented from the supplied manuscript

- Target cohort: **36 Flock 4H satellites**; **1 March–31 August 2026**, 184 dates.
- Primary pairing: absolute native epoch separation **at most 1 ms**.
- Separate sensitivity: **at most 24 hours**; extra asynchronous cases never
  replace the primary sample. Both full wide-window and asynchronous-only summaries
  are exported. The latest eligible daily state can differ between these samples.
- One guard archive date before/after the study; no silent expansion of the window.
- Same satellite; nearest eligible TLE; equal-distance tie favours earlier epoch.
- At most one accepted pair per satellite/UTC day, using the **latest eligible**
  Cartesian epoch. A later ineligible state does not hide an earlier eligible one.
- Conflicting payload revisions at one identity/epoch are excluded until resolved.
- Weekly sensitivity: **first accepted pair per satellite/ISO week**, including
  partial boundary weeks. Daily sampling remains primary.
- Signed residual: **SGP4-evaluated TLE minus Cartesian**. RTN axes from Cartesian
  position and velocity; velocity remains an inertial three-vector difference.
- Pooled, satellite, month and satellite-month summaries; equal-satellite RMS and
  leave-one-month-out sensitivity.
- Non-circular calendar-date moving blocks: **7 days**, **2,000** replicates;
  **3/14-day** sensitivity; at least **1,900 valid replicates** per interval.
  Empty dates are retained; all satellites on a selected date move together.
  There is no imputation and no redrawing to replace invalid replicates.

No numerical gravity/drag/SRP branches, Cartesian propagation, correction fitting,
forecast-horizon scores, or best-propagator selection are included.

## What must be reviewed before `research` mode

The manuscript requires verified identities and bounded time/frame processing.
The project deliberately does not mark these as solved merely to obtain numbers.

### Identity roster

[`config/roster.csv`](../config/roster.csv) contains 36 **candidate** HWID–catalogue mappings transcribed
from Planet's public matching report (snapshot text dated 2026-06-11). All real
`HistoricallyVerified` fields are **false**. Current/one-date matching does not
prove six-month validity. Confirm the historical mappings and validity intervals,
record evidence, and change only the approved rows. The archive's TLE header HWID
is checked as additional corroboration. Unverified records cannot enter a research
sample. Catalogue changes can be represented by non-overlapping roster intervals.

### Frames

Choose an explicit policy in `cfg.frames.cartesianMode`:

- `identity_assumption`: an adopted J2000 ≈ ICRF interpretation, not a proof of
  equivalence. Appropriate for flagged pilot work; research requires its independent
  justification and a documented precision assessment.
- `fixed_rotation`: supply a reviewed 3-by-3 proper rotation. Both position and
  velocity are rotated because this mapping is time-independent.
- `custom`: supply a named function `[rI,vI]=f(utc,r,v)` implementing a documented
  full-state transformation, including a time-derivative term when applicable.

Record `cfg.frames.evidence` and set `policyApproved=true` only after review.
For the ground metric, observed IERS/USNO `finals2000A.all` values are used with
`dcmeci2ecef('IAU-2000/2006',...)`, including UT1, polar motion and dX/dY.
No Earth-orientation extrapolation or zero-EOP fallback is automatic.

### SGP4 verification

Use `run_tests`, MATLAB `checkcode`, documented SGP4 test cases and an independent
common-frame comparison where available. `verify_against_reference.m` accepts an
independently generated ICRF reference CSV. A wrapper smoke test alone is not an
independent numerical verification. Record `cfg.sgp4.verificationEvidence` and set
`verificationApproved=true` only after verification. The built-in SGP4 frame mapping
and constants are fixed by the installed MATLAB implementation; its version is logged.

Then use `cfg=study_config("research")`, apply the reviewed overrides, and call
`run_study(cfg)`. Research mode refuses unresolved frame policies and unverified
SGP4 settings, and excludes unapproved identities. These are deliberate safety gates,
not silently substituted parameter defaults.

## Precision and physical conventions

TT is represented internally as **int64 nanoseconds relative to J2000 TT**.
TLE fractional-day units are parsed exactly (one 1e-8 day unit = 864000 ns),
and `.states` decimal seconds are parsed without multiplying a large floating-point
number by 1e9. The 1 ms eligibility decision uses these integer values, not Julian-date
subtraction. Integer storage preserves source resolution; it does not imply nanosecond
knowledge of the physical orbit or MATLAB's internal propagation timing.

An explicit leap-second table is included, reviewed for the configured study window.
The MATLAB datetime conversion and `tleread` epoch are independently checked against
that representation. Leap-second instants themselves are rejected rather than
folded onto midnight. Extending the time window requires reviewing the leap table.

The native TLE mean parameters and `BStar` are preserved. Planet's drag and SRP
coefficients are retained only as metadata. Infinite/unfitted SRP does not invalidate
position/velocity data. Each historical TLE is isolated before `tleread` to prevent its
latest-record-per-catalogue behaviour from replacing the selected record.

Ground distance uses simultaneous WGS84 **ellipsoid-normal footpoints**, not a
nearest-point distance between complete tracks. The default backend is Mapping
Toolbox `distance` with an explicit metre ellipsoid. An explicitly selectable
Vincenty implementation supports the offline demo; it raises on nonconvergence and
never substitutes a spherical distance. The code does not claim MATLAB uses Karney
internally.

## Full study outputs

Each run creates a new timestamped folder with configuration and code hashes,
source-file manifests, stage MAT snapshots, and tables including:

- `states.csv`, `tles.csv`, `record_occurrences.csv`, `parse_log.csv`;
- both sample candidate-decision tables and selected daily pair tables;
- `evaluated_states.csv`, `paired_residuals.csv`, failure tables;
- `table3_coverage.csv`, `table4_pooled_state_ground.csv`, `table5_rtn_all_groups.csv`;
- satellite/month summaries, `summary_all.csv`, weekly records, bootstrap intervals;
- `results.mat`, `RUN_REPORT.md`, figures as PNG and editable FIG.

RMS averages vector squared norms with **no division by three**. Signed means are
relative product offsets; sample standard deviations use N−1 and are NaN at N=1.
All percentile calculations use an explicitly documented type-7 convention.
All metrics within a summary use the same successful pairs. Ground conversion
failures exclude the pair from joint summaries but preserve its computed state
metrics and the failure message in the residual table.

Archive-date age bounds are stored separately for both products and labelled as
proxies. Publication times are not inferred from filenames or download times;
causal freshness analyses are not produced automatically.
