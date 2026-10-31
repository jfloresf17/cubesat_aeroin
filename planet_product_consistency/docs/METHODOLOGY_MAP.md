# Manuscript-to-code traceability

For a first run, use `study_config` and `run_study` with the
[MATLAB analysis guide](ANALYSIS_GUIDE.md). The complete MATLAB implementation
mapped below covers acquisition through RTN/ground metrics, summaries and
reporting. Full settings and approvals are described in the
[research protocol](RESEARCH_PROTOCOL.md).

Source: `PlanetScope_Consistency_SmallSat.pdf`, the eight-page SmallSat draft attached
with the coding request. This takes precedence over older six-satellite drafts.

| Manuscript | Implementation | Test/output |
|---|---|---|
| §3.1 target 36, March–August, maximum 6624 | study_config, roster, acquire | coverage.csv; no fabricated coverage |
| §3.1 immutable originals and duplicate/revision audit | fetchCached, readStates, readTLE, cleanRecords | occurrences.csv, test_parsing |
| §3.2 Eq. 2 nearest eligible TLE, earlier tie | pairing.build | test_pairing |
| §3.2 primary 1 ms; separate 24 h | two separate calls to pairing.build | primary/wide decision tables |
| §3.2 Eq. 3 TT/UTC reconciliation | time.decimalNs, tleEpoch, ttToUTC, utcToTTns | test_time |
| §3.2 Eq. 4 full-state mapping | frames.planetToICRF | approved identity/rotation/custom policy |
| §3.2 unchanged native SGP4 | propagation.evaluatePairs | BStar/ID/epoch assertions; conditional smoke test |
| §3.3 Eqs. 5–6 signed residuals | metrics.stateResidual | 3-4-12 known-vector test |
| §3.3 Eqs. 7–8 RTN | metrics.stateResidual | orthonormality, norm conservation |
| §3.3 Eqs. 9–12 norms/RMS/mean/SD | stats.point | identity RMS²=mean²+(N−1)/N*SD² |
| §3.3 Eqs. 13–14 ground separation | frames.earthRotation, metrics.groundDistance | equatorial geodesic/geodetic tests |
| Ground direction extension | metrics.groundDistance, stats.point, reporting.figures | Signed geographic east/north statistics and plots; scalar ground distance retained |
| §3.4 pooled/satellite/month | stats.aggregate | summary_all.csv and tables 4–5 |
| Table 2 weekly thinning | pairing.weekly | first chronological accepted pair per ISO week |
| Table 2 moving blocks 7/3/14, 2000/1900 | stats.bootstrap, drawDateBlocks | test_bootstrap; intervals with valid counts |
| §3.4 age proxies | pairing.build | separate lower/upper bounds; unapproved by default |
| §4.1 verification and exclusions | preflight, eval/metric failures, verify_against_reference | retained failures; no zero substitutes |

## Definitions used in results

`Position_m = norm(r_TLE_ICRF - r_Cartesian_ICRF)` and the analogous velocity norm.
The Cartesian position/velocity defines the RTN orientation, not a truth orbit.
The bootstrap resamples **calendar-date clusters** and never selects only one week
per month. Empty dates remain eligible blocks. For monthly intervals, the sampling
window is that calendar month, clipped to the study bounds.

The parent OD solution and full source frame realization are not identifiable from
these calculations. The project cannot certify either product's absolute accuracy.
