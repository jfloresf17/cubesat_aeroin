# Data and software notices

The project code is MIT-licensed; see [LICENSE](LICENSE).

Planet-derived identity fields in `config/roster.csv` and the short TLE smoke-test
record are attributed to Planet Labs PBC, Public Orbital Ephemerides,
https://ephemerides.planet-labs.com/ , whose ephemeris data are provided under
CC BY-NC 4.0. These data retain that separate licence; they are not relicensed MIT.
The roster has not been historically verified. Its proposed validity intervals
cover the study and guard dates; the false approval flags must remain until review.

The active analysis workflow uses MATLAB only. No external language runtime
is required for analysis; third-party orbit software is not vendored here.

NAIF-derived historical leap-second dates and offsets are attributed in
`docs/SOURCES.md`. No MATLAB, SGP4 library, or full third-party code is redistributed.
The optional Vincenty routine is an original implementation of the published
algorithm; numerical and edge-case verification is required on the target runtime.
