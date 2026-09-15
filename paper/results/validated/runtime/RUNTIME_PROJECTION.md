# Measured workload projection

High-B reference: `/home/amir/repo/di-oscar-accessible/code/roscar/paper/simulations/quick/d47f33665e35` (B = 20).
Low-B reference: `/tmp/roscar-driver-qc/runs/3487c608f4c3` (B = 2).

For each setting, fit the two-point timing model T(B) = F + b*B. The per-resample cost b is the difference in average completed job times divided by the difference in B; F is the remaining fixed cost. Negative fitted components are truncated at zero.

Total projected worker-seconds sum 500*F + inference_reps*200*b across the 87 settings. Divide by workers*3600 to obtain hours. The CSV inputs and formula make this projection reproducible.

This assumes approximately linear throughput when changing worker count. Machine load, cache behavior, and method refitting can change actual runtime. The pilot uses the final core; the earlier quick run additionally exercises the initial integration version. No point-performance or coverage outcome enters the compute decision.
