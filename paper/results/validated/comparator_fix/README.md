# Comparator correction integration check

Seven prespecified cases cover all six scenarios and both Scenario 5 treated-arm nuisance specifications. Each supported comparator receives 20 bootstrap resamples. Pooled fitting is explicitly unavailable in the mismatched-covariate scenario.

Run from the package root: `Rscript paper/simulations/check-comparators.R`.
The CSV records the actual design, replication and fixed-test seeds, resample counts, and source checksum. source_manifest.csv lists the source files contributing to that checksum.

The check verifies execution of the corrected interaction and pooled models. A separate noiseless nonlinear null-effect regression test verifies the mathematical reason for the correction; this small run provides no coverage or performance evidence.
