# Implementation choices and outstanding scientific decisions

These are not new findings about Planet. They make unspecified supplementary details
visible rather than silently replacing the manuscript.

## Directly inherited

36 target satellites; March–August; one accepted daily pair; 1 ms primary and 24 h
separate sensitivity; nearest/earlier tie; first accepted ISO-week pair; unchanged
SGP4; signed RTN; 7-day/2000 bootstrap with 3/14-day checks and 1900 valid replicates.

## Explicit implementation decisions

1. **Canonical raw occurrence:** the earliest collected archive occurrence of an
   identical payload is the record's canonical source. Every occurrence is retained
   separately. This makes repeat accounting independent of processing order.
2. **Revision policy:** different normalized payloads at one identity/native epoch
   are excluded as unresolved revisions, even if differences concern metadata or TLE
   element-set counters. No latest-wins assumption. Investigate excluded revisions
   before adopting a less conservative rule.
3. **Daily rule:** pair all eligible Cartesian records first, then retain the latest
   eligible native epoch within each UTC day. This is not selecting the smallest
   residual. Primary and wide samples make their daily selections independently.
4. **Identity corroboration:** the TLE header HWID must match the approved/catalogue
   roster identity by default. A current matching report is candidate evidence only.
5. **Precision gates:** datetime round-trip ≤10 microseconds and independently parsed
   `tleread` epoch difference ≤0.1 ms. These are processing screens, not orbit-error
   guarantees. The actual implementation's resolution still needs local verification.
6. **Leap-second scope:** included table is reviewed for this study, with validity
   through 2 September 2026. The exact inserted leap-second instant is rejected
   because ordinary MATLAB UTC datetime is not used to represent :60 here.
7. **Quantile convention:** type 7, h=1+(N−1)p, with linear interpolation. Integer
   bootstrap frequency weights reproduce quantiles of the expanded sample exactly.
8. **Bootstrap support:** require at least max(14, 2L) distinct occupied dates and a
   window of at least 2L calendar days for block length L. Per-statistic intervals
   require at least 1900 valid replicates in research settings. No redraw. This is a
   conservative added support rule because the supplementary rules were not supplied.
9. **Stationarity:** intervals are labelled conditional on stationarity and short
   dependence within the relevant window. No automatic test establishes these
   assumptions. A trend or processing change calls for reassessment, not automatic
   interpretation of the global interval.
10. **Equal-satellite sensitivity:** only RMS quantities are equal-weighted across
    represented satellites, by averaging their mean squares before rooting. Percentile
    and SD fields are NaN in those rows to avoid silently changing their estimands.
    Bootstrap intervals are for pair-weighted daily summaries, not the equal-satellite
    sensitivity. The latter and leave-one-month-out changes are descriptive summaries.
11. **Common sample for metrics:** summaries use successful state AND ground metrics.
    A ground failure is explicit and the partial state result remains inspectable.
12. **Age proxies:** [archive-date midnight − native epoch, next midnight − native
    epoch) bounds are calculated from a date label, not measured publication times.
    Their interpretation needs an approved archive-date convention. Association
    analysis is intentionally not automated from unapproved proxies.
13. **Frame policy:** the Planet J2000 label is not enough to prove an exact ICRF
    mapping. Research mode requires a recorded adoption and precision review; it
    does not infer the right interpretation from low residuals. Fixed rotations use
    the same rotation for velocity; time-dependent custom mappings must handle Cdot.
14. **EOP:** Bulletin-A observed UT1/polar motion/dX/dY, linear interpolation of
    UT1−TAI across endpoints, no extrapolation. Predictions are off by default.
15. **Missing network data:** files are reported missing/failed; they are never
    replaced with current ephemerides or a synthetic reference.
16. **Ground east/north extension:** retain the manuscript's scalar WGS84
    inverse-geodesic distance, then resolve that distance using the initial
    forward azimuth at the Cartesian-derived footpoint towards the TLE-derived
    footpoint. East = distance × sin(azimuth), north = distance × cos(azimuth),
    with azimuth clockwise from north. These are distance-and-bearing components
    in the local geographic directions, not the projection of the satellite's
    3D residual into RTN or an independently measured image displacement. They
    satisfy east² + north² = ground-distance². At coincidence, components are
    zero and bearing is undefined. Inspect signed results by satellite and date:
    a pooled mean can conceal opposite directional offsets.

## Decisions the researcher must approve

Historical roster intervals; frame interpretation/evidence; local SGP4 and frame
verification; adequacy of source timestamp resolution for the 1 ms screen; EOP
coverage; support/stationarity for bootstrap reporting; archive-date conventions.
None is solved merely by setting an approval flag. Keep the evidence with the run.
