# Documentation

This directory documents the MATLAB workflows, their data sources and the
interpretation of their results. Start with the [repository README](../README.md)
for installation and execution commands.

| Guide | Use it for |
|---|---|
| [MATLAB setup](MATLAB_SETUP.md) | Installation, licensing, toolbox and Java checks, VS Code and terminal use |
| [PlanetScope quick look](QUICKLOOK.md) | Planet API credentials, year and time filters, catalogue matching and previews |
| [Footprint methodology](FOOTPRINT_METHODOLOGY.md) | Research design, sensor-ray and swath assumptions, orbital and footprint metrics |
| [Analysis guide](ANALYSIS_GUIDE.md) | Stages and outputs for the separate Cartesian-epoch orbital consistency study |
| [Research protocol](RESEARCH_PROTOCOL.md) | Identity, Earth-frame and independent SGP4 review requirements |
| [Data dictionary](DATA_DICTIONARY.md) | Native record fields and the original study's output conventions |
| [Sources](SOURCES.md) | References, data provenance and licensing context |
| [Decisions](DECISIONS.md) and [methodology map](METHODOLOGY_MAP.md) | Original manuscript traceability and assumptions |
| [Integration notes](INTEGRATION.md) | Historical notes on the proposed upstream integration |

The quick look uses actual available archives and Planet catalogue data. A
time match is not proof that image-centre timing is exact or that an orbital
product is independent ground truth. The footprint methodology distinguishes
implemented functions from proposed research and states the assumptions that
must accompany interpretation.

Generated runs and downloaded Planet data belong under ignored data/results
paths; source-code and data licences are described in [NOTICE.md](../NOTICE.md).
