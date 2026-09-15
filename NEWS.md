# roscar 0.1.0.9000

* Add validated trial/external constructors and observed-arm design probabilities.
* Add Recipes A/B/C/D, grouped cross-fitting, pluggable offset learners, and
  a prespecified formula interface for final treatment-effect regression.
* Add full trial bootstrap inference, paired trial-only comparisons, and diagnostics.
* Implement linear CALM with externally standardized supervised PLS and ridge mapping.
* Preserve Cole Beck's original `cate_model()` functions and package history;
  provide the legacy one-arm R-OSCAR function for reproducibility.
* Add six simulation scenarios, teaching example, STAR reconstruction, and
  code-only protected Greenlight analysis.

The release remains a development version while full paper results and external
platform checks are pending. Binary link calibration is implemented and tested;
continuous-outcome simulations do not establish its coverage. Neural/Bayesian
CALM and survival models are outside this version.
