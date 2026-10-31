# Integration with cubesat_aeroin

This directory contains the PlanetScope consistency study. It coexists with the
repository's root-level Planet ephemerides downloader; it does not replace that
downloader, its entry point or its tests. Each workflow has its own requirements.

Run the consistency study from this directory using the commands in its
[README](../README.md). It compares native Cartesian states and TLEs at scene
acquisition times and uses MATLAB Aerospace and Mapping toolboxes. A new
PlanetScope catalogue search also needs a Planet Data API key. The root-level
public ephemerides downloader does not require that key.

Downloaded inputs and generated results are ignored by the nested `.gitignore`.
When reusing compatible native archive files produced by the downloader, point
the quick-look configuration at their location and check the expected filenames,
source provenance and coverage. Review the identity, time, frame and SGP4 gates
before interpreting research results; see the [research protocol](RESEARCH_PROTOCOL.md)
and [footprint methodology](FOOTPRINT_METHODOLOGY.md).

For example, from the `planet_product_consistency/` directory in a checkout
whose root downloader uses its default cache:

```matlab
q = quicklook_config();
q.RawPath = fullfile(fileparts(pwd), 'data', 'planet_ephemerides', 'raw', 'daily');
q.TimeToleranceSeconds = 1;
q.DownloadThumbnails = false;
search = quicklook_inspector(q);

opts = footprint_study_config(2026);
opts.QuicklookMAT = fullfile(search.RunDir, 'quicklook_results.mat');
result = run_footprint_study(opts);
```

The scene search requires a Planet API key and covers only the available
archive windows. Adjust the dates for the intended study.
