# Validated public output snapshots

These are named aggregate tables, figures, seeds, and provenance records copied from completed public runs. The manifest records file checksums. No individual STAR records, unlicensed comparison extract, fitted-model checkpoints, or Greenlight outputs are included.

Simulation quick mode uses 10 replications and B=20 and checks execution only. The anomaly analysis uses 200 point-performance replications without bootstrap intervals. Full simulations use the counts recorded in their seed ledger and performance table. STAR quick mode uses one source construction per trial fraction and B=20; full mode uses 30 and B=500.

If a simulation directory contains SUPERSEDED_METHODS.csv, its listed scenario/method rows are omitted from the public copied tables. The marker gives the reason; the original local checkpoints are preserved. Replacement checks and full runs use the corrected implementation.

Only directories actually present are completed snapshots. An absent full directory means final results remain pending. Performance tables retain failures and unavailable targets; coverage is conditional on successful intervals. Consult the application README for STAR dependence and allocation limitations.
