# Technical sources and provenance

Consulted 30 October 2026. These sources specify data or software behaviour, not
empirical results produced by this project.

1. User-supplied `PlanetScope_Consistency_SmallSat.pdf`, pp. 3–5, Sections 3.1–3.4:
   target cohort, time windows, pairing, metrics, aggregation and bootstrap settings.
2. Planet Labs PBC, public orbital ephemerides:
   https://ephemerides.planet-labs.com/
   `.states` columns, epoch/frame/units, historical paths, telemetry-dependent updates,
   identity caveats and CC BY-NC 4.0 data licence.
3. Planet public matching report:
   https://ephemerides.planet-labs.com/18SPCS_matches_v1.txt
   Retrieved web text was stamped **2026-06-11T10:43:06Z**. The candidate 36-member
   roster is transcribed from that text; it is NOT a historical-validity certification.
   The running MATLAB code archives a separate local report snapshot when accessible.
4. MathWorks, `propagateOrbit` (R2024b+):
   https://www.mathworks.com/help/aerotbx/ug/propagateorbit.html
   Native general-perturbations input, ICRF output, SI units, SGP4 argument restrictions.
5. MathWorks, `tleread`:
   https://www.mathworks.com/help/aerotbx/ug/tleread.html
   Only latest epoch per catalogue number is retained unless selected records are isolated.
6. MathWorks, `dcmeci2ecef`:
   https://www.mathworks.com/help/aerotbx/ug/dcmeci2ecef.html
   IAU-2000/2006 reduction, explicit deltaAT, DUT1, polar motion and CIP corrections.
7. NASA NAIF, `naif0012.tls`:
   https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls
   Source of the tabulated historical TAI−UTC values. TT = TAI + 32.184 s;
   this project does not apply the periodic TDB−TT terms also described in that kernel.
8. USNO/IERS, finals2000A format:
   https://maia.usno.navy.mil/ser7/readme.finals2000A
   https://maia.usno.navy.mil/ser7/finals2000A.all
9. MathWorks, `distance`:
   https://www.mathworks.com/help/map/ref/distance.html
   Explicit ellipsoid required for an ellipsoidal length in its semimajor-axis units.
10. Karney, C. F. F. (2013). Algorithms for geodesics. Journal of Geodesy 87, 43–55.
    DOI: 10.1007/s00190-012-0578-z. Verification basis, not a claim about MATLAB internals.
11. Vincenty, T. (1975). Direct and inverse solutions of geodesics on the ellipsoid
    with application of nested equations. Survey Review 23(176), 88–93.
    DOI: 10.1179/sre.1975.23.176.88. Explicit optional/demo geodesic backend.
12. Künsch, H. R. (1989). The jackknife and the bootstrap for general stationary
    observations. Annals of Statistics 17(3), 1217–1241. DOI: 10.1214/aos/1176347265.
    The manuscript adopts a moving-block bootstrap; its 7/3/14 choices are study settings.
13. Vallado, D. A., Crawford, P., Hujsak, R., Kelso, T. S. (2006). Revisiting Spacetrack
    Report #3. DOI: 10.2514/6.2006-6753.
    https://celestrak.org/publications/AIAA/2006-6753/

No full third-party SGP4 implementation is redistributed. The test smoke TLE is a
short Planet public-record example. Test fixtures used to check the software are
not research observations. Planet source products downloaded at runtime remain
subject to their separate data licence.

For the ground projection convention, [NAIF's MATLAB `cspice_subpnt`
documentation](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/MATLAB/mice/cspice_subpnt.html)
distinguishes the nearest ellipsoid point from the center-line intercept.
[Skyfield's subpoint documentation](https://rhodesmill.org/skyfield/earth-satellites.html#satellite-latitude-longitude-and-height)
describes `wgs84.subpoint_of` using geodetic latitude/longitude and zero
ellipsoidal height. These references explain the convention; they do not establish
numerical agreement among software or replace verification of the MATLAB pipeline.

The Cartesian frame interpretation remains an adopted pilot assumption. Neither
the cited projection definitions nor a MATLAB software run independently verify
historical satellite identity, orbital accuracy, or the SGP4 implementation.
