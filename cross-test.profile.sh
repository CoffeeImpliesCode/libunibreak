# cross-test settings profile for libunibreak.
#
# `cross-test` looks for this file at the root of the project it is run from
# (or names it with --profile; --no-profile ignores it). It is trusted Bash that
# the harness `source`s, so this file is *settings only*: ordinary variable
# assignments and nothing else. No command runs, no compiler is probed, and no
# path in here names a host.
#
# There is deliberately no CROSS_MATRIX. The published 53-platform Zig 0.16
# Tier 1/2 table is the matrix this package is checked against, and a matrix
# named here would replace it. There is no TARGETS array either, for the same
# reason: a subset selected here would narrow the run rather than add to it.
# Both belong on the command line, where --targets selects from the active
# matrix and never adds to it.
#
# CROSS_BUILD_STEP stays the standard `test` step, which is what this profile
# states explicitly. There are no `cross_build_command` / `cross_artifact`
# hooks here, so the harness keeps its standard Zig-build mode and runs
# `zig build test -Dtarget=TARGET` per target with a fresh cache. What that
# means for a given target is the harness's decision, not this package's: a
# host target runs, a foreign target runs under whatever executor the harness
# detects (QEMU user mode, Wine, wasmtime), and a foreign target with no
# executor is reported as build-only coverage -- compiled, never executed, and
# never counted as a pass. `build.zig` gives the test binary a Run step for
# every target, which is what leaves that choice open.
#
# A target graph compiles the nine core translation units of src/Makefile.am,
# translates the five public headers, and links the facade and the test root.
# Keep four build jobs available.
#
# Every test in tests.zig reads the three Unicode conformance fixtures whole --
# src/LineBreakTest.txt is about 3.1 MB, src/WordBreakTest.txt about 322 KB and
# src/GraphemeBreakTest.txt about 127 KB -- and there is no sampling anywhere in
# this package. Allow a bounded longer run so a cell that needs it is not cut
# off mid-corpus. If a cell does hit a deadline, that is a fact to record and
# diagnose: do not sample the corpus, do not skip rows, and do not remap Debug
# to an optimized mode to make it pass.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=3600
CROSS_TIMEOUT=1800

# `-Dlinkage` and `-Druntime` are deliberately absent here, and that is a
# statement rather than an oversight. The matrix is a *target* matrix: its
# question is which platforms this package builds and runs its tests on, and
# varying the delivery would replace that question with another one. The
# harness runs `zig build test -Dtarget=TARGET`, so every cell is the static
# linked graph — the configuration this SDK produced before those options
# existed. Shared delivery and the runtime dispatch are separate gates over the
# same six targets — `zig build check -Dtarget=T -Dlinkage=dynamic` for each
# target that has a dynamic linker, and a refusal for `wasm32-wasi`, which has
# none — and their behavioural gates. A cell here is never evidence for either,
# and neither is a reason to narrow this matrix.