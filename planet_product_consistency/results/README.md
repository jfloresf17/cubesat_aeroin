# Generated results

The MATLAB workflows write timestamped run directories here. A fresh checkout
does not contain generated research outputs. See the [project README](../README.md)
for setup and commands.

`run_footprint_study` writes a run-specific `RUN_REPORT.md`, matching and
coverage inventories, orbital and footprint metrics, figures, and a MAT file.
The report and tables identify exclusions, assumptions and failures; inspect
them before interpreting the results. If the quick-look inspector must search
the Planet catalogue, it creates a separate timestamped quick-look directory.

The separate `run_study` workflow also attempts to publish a stable
`results/RUN_REPORT.md`. Its returned context records whether publication
succeeded; its timestamped run directory retains the original report.

Generated outputs are ignored by Git. Create results from actual input data,
and review provenance and Planet's data licence before sharing derived products.
