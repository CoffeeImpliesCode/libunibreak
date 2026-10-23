# Settings-only profile; keep the harness's full default matrix and test step.
# Full Unicode fixtures need longer timeouts; tests do not sample them.
# This profile tests static linkage; shared and runtime configurations are separate.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=3600
CROSS_TIMEOUT=1800

# Shared and runtime linkage use separate checks.