//! Zig 0.16 build for the libunibreak Unicode line, word and grapheme breaking
//! library.
//!
//! The library is upstream's own C, byte for byte: the nine translation units
//! of `src/Makefile.am`'s `libunibreak_la_SOURCES` and the five public headers
//! of its `include_HEADERS`, nothing else. Nothing is downloaded, no
//! autotools, Make or configure script is executed, and the default mode
//! compiles everything from this repository rather than linking an installed
//! copy.
//!
//! Upstream reference: tag `libunibreak_8_0`, `configure.ac`'s
//! `AC_INIT([libunibreak],[8.0],...)` and `src/unibreakbase.h:42`
//! (`#define UNIBREAK_VERSION 0x0800`). The pinned commit SHA belongs in
//! `FORK-NOTES.md` and `UPSTREAM.md`, which the fork's provenance owner writes
//! from `git log`; this script does not restate a SHA it cannot read.
//!
//! Entry points
//! -----------
//!   zig build            install the native library, the five public headers,
//!                        upstream's `LICENCE`, the carried Unicode terms,
//!                        upstream's own README, the pkg-config metadata, and
//!                        compile the example program
//!   zig build test       run the facade tests for the selected target
//!                        (`-Dtarget`; the host when it is absent)
//!   zig build smoke      run the example program
//!   zig build exercise   run the API exercise: every public facade method and
//!                        every translated entry point once
//!   zig build upstream-test
//!                        build and run upstream's own unmodified `src/tests.c`
//!                        against the three Unicode fixtures, from `src/`
//!   zig build consumer   build the separate `consumer/` package, which reaches
//!                        this one through `dep.module("libunibreak")`, and run
//!                        it when this host can execute the selected target
//!   zig build check      compile the C core, the facade, the API exercise, the
//!                        tests, the example and upstream's own C harness for
//!                        the six-target matrix, running nothing
//!
//!   cross-test           the same `test` step, for the published 53-platform
//!                        Zig 0.16.0 Tier 1/2 table rather than the host alone.
//!                        `cross-test` discovers `cross-test.profile.sh` from
//!                        the package root, runs `zig build test -Dtarget=TARGET`
//!                        for each of them, and executes the binary where a
//!                        runner exists and records explicit `build_only`
//!                        coverage where one does not. `test` is what the
//!                        harness reaches for, and it builds the same graph and
//!                        the same test binary for whatever `-Dtarget` says:
//!                        nothing in `build()` narrows the graph to the host,
//!                        and the `check` matrix below is compile-only and is
//!                        not a substitute for it.
//!
//! Options
//! -------
//!   -Dlinkage=static    a static archive, `libunibreak.a`. This is the
//!   -Dlinkage=dynamic     default and it is what this package produced before
//!                         the option existed, so a caller who passes nothing
//!                         changes nothing. `dynamic` builds a real shared
//!                         object with upstream's own soname; see "Static and
//!                         shared delivery" below.
//!   -Druntime=true      resolve the native entry points at run time instead
//!                        of linking them. The facade keeps the same translated
//!                        header and the same public types; each selected native
//!                        function becomes a dispatch through one
//!                        process-lifetime table an explicit `load(source)`
//!                        fills, and the module links no archive. Independent
//!                        of `-Dlinkage`, which still decides which artifact
//!                        this build delivers and installs. Default off, and a
//!                        linked build is unchanged in every respect. The
//!                        dispatch itself is `runtime/graph.zig`, which the API
//!                        role owns; `addGraph` names the exact seam.
//!   -Dtarget=<triple>   build for one target; `zig build check` then checks
//!                        that target only instead of the whole matrix.
//!   -Doptimize=<mode>   the caller's mode, passed to every graph below. No
//!                        target-specific or mode-specific branch exists in
//!                        this file: the facade, the C core and the upstream
//!                        harness are compiled the same way in Debug and
//!                        ReleaseSafe, so a bound that one mode checks and the
//!                        other does not cannot be written into them.
//!
//! There is no system-library mode in this wave, by contract: the source pin
//! and the bounded contracts must stay identical in every mode, and a real
//! installed libunibreak with matching headers is not something this repository
//! can promise to any of the six matrix targets. So the rule is recorded as NOT
//! APPLICABLE rather than claimed as a satisfied gate, and nothing here links
//! `-lunibreak`. There is likewise no `b.systemIntegrationOption` call: an
//! unused option is a knob nobody has checked, and a mode that cannot be
//! entered is better named in this comment than half-built behind a flag.
//!
//! Static and shared delivery
//! --------------------------
//! `-Dlinkage` selects which artifact this package produces, and the default
//! is the one this SDK has always produced: `static`, so a caller that passes
//! nothing gets the same `libunibreak.a` it got before the option existed.
//! Nothing about the compiled C changes between the two: the same
//! `core_sources`, the same language level, the same `UNIBREAK_LAZY_INCB`
//! value, the same header and the same include path. The option selects the
//! *delivery*, never the dispatch.
//!
//! `dynamic` is a real shared object, and it takes three things this build
//! would otherwise not do. Two of them come straight out of upstream's own
//! libtool line, `src/Makefile.am:10`,
//! `libunibreak_la_LDFLAGS = -no-undefined -version-info 8:0:0`:
//!
//!   * **A real soname, and it is upstream's number.** Libtool reads
//!     `-version-info current:revision:age` and derives both the file name
//!     and the `DT_NEEDED` name from it: the library is
//!     `libunibreak.so.(current-age).(age).(revision)` and the soname a
//!     consumer records is `libunibreak.so.(current-age)`. At `8:0:0` that is
//!     `libunibreak.so.8.0.0` with the soname `libunibreak.so.8`, which is
//!     what `abi_version` below asks `b.addLibrary` for, and what
//!     `std/Build/Step/Compile.zig:488-515` turns into that shape (and
//!     `:1824-1832`, with `wantSharedLibSymLinks` at
//!     `lib/std/Build.zig:2717-2719` saying there are no symlinks on Windows,
//!     where `unibreak.dll` and its import library `unibreak.lib` land instead).
//!     Nothing here invents an ABI number: `8` is upstream's own `current`,
//!     and it is what a `libunibreak.pc` consumer's `DT_NEEDED` already records.
//!     On Darwin the same value gives
//!     `libunibreak.8.dylib` with the install name `@rpath/libunibreak.8.dylib`.
//!   * **No undefined symbols.** `-no-undefined` is what makes upstream's
//!     `libunibreak.la` a linkable shared object rather than one that expects
//!     the linker's help. Here it is structural rather than a flag: the nine
//!     translation units are compiled into the same `b.addLibrary`, and the
//!     only external symbol any of them needs is libc, which `link_libc`
//!     brings.
//!   * **Position independence**, which a shared object requires and an archive
//!     does not. `addCoreLibrary` sets `.pic = true` on the library's own
//!     module in that mode and leaves it unset for `static`, so the static
//!     build's C command line is unchanged from before `-Dlinkage` existed.
//!     There are no independently compiled objects in this library to worry
//!     about: unlike BLAKE3's per-instruction-set kernels, libunibreak's whole
//!     closure is one module, so one flag on one module reaches every
//!     translation unit.
//!
//! **The export surface is upstream's default, because upstream declares
//! none.** This is the one place where the obvious shared-library recipe
//! would be an invention here. BLAKE3 widens exactly one macro,
//! `BLAKE3_API`, and can therefore compile with hidden default visibility; the
//! five libunibreak public headers declare plain undecorated functions and
//! plain `extern const int unibreak_version`
//! (`src/unibreakbase.h:43`, defined at `src/unibreakbase.c:38`) and contain no
//! `__attribute__((visibility))`, no `__declspec` and no `dllexport`/`dllimport`
//! pair anywhere — upstream's `src/Makefile.am:9-10` passes `-W -Wall`,
//! `-no-undefined` and nothing else, and `src/Makefile.gcc:89` passes
//! `-W -Wall` only. So this build adds **no** `-fvisibility=hidden` and **no**
//! version script: with nothing annotated, hidden default visibility would
//! export nothing at all, and a hand-written export list beside headers that
//! state none could only drift from what upstream ships. What the shared object
//! exports is therefore upstream's own behaviour, the default-visibility set,
//! and the five public headers are what a consumer is documented to call.
//!
//! That also settles the DLL question honestly rather than by inventing a
//! macro: there is no import/export distinction in these headers to reproduce,
//! so none is fabricated. On Windows the exported set of `unibreak.dll` is
//! whatever the toolchain emits for a DLL with no export declarations, and
//! that is a fact for a gate to read out of the produced binary rather than
//! something this build can promise from the source.
//!
//! A target that cannot carry the requested linkage is refused, never answered
//! with the other one. WASI has no dynamic linker — `std.Target.DynamicLinker.kind`
//! is `.none` for it (`lib/std/Target.zig:2345-2402`) — so `-Dlinkage=dynamic`
//! for `wasm32-wasi` stops at configure time with a message naming the target
//! and `-Dlinkage=static`, and `zig build check -Dlinkage=dynamic` gives that
//! matrix cell a failing step of its own rather than compiling it as something
//! else. The default `static` is a separate answer and keeps working for every
//! one of the six targets, and the matrix is never narrowed: six cells in,
//! six results out, and the unsupported one says why.
//!
//! The reason for refusing rather than falling back is that a caller who asked
//! for a shared object and received an archive has been given something other
//! than what it asked for, and cannot tell from the result that the delivery it
//! is testing is not the delivery it requested. A warning in front of that
//! would not make it distinguishable at the consumer that matters.
//!
//! Installed closure
//! -----------------
//! `zig build` installs:
//!
//!   * the native library in whichever `-Dlinkage` selected, through
//!     `b.installArtifact`. On ELF a shared install is `libunibreak.so.8.0.0`
//!     with `libunibreak.so.8` and `libunibreak.so` beside it; on Darwin
//!     `libunibreak.8.0.0.dylib` with `libunibreak.8.dylib` and
//!     `libunibreak.dylib`; on Windows `unibreak.dll` under `bin/` with its
//!     import library `unibreak.lib` under `lib/`, which is where
//!     `std/Build/Step/InstallArtifact.zig:61-67` puts a DLL versus everything
//!     else. The Windows names carry no `lib` prefix because
//!     `std.zig.binNameAlloc` only prepends `t.libPrefix()` for ELF and Mach-O
//!     (`lib/std/zig.zig:160-206`), and that is the same reason the artifact is
//!     named `unibreak` rather than `libunibreak`.
//!   * the five public headers under `include/`, through the `installHeader`
//!     calls in `addCoreLibrary`. Installing a header also puts it on the
//!     include path of anything that links this artifact, so a C consumer
//!     needs nothing from this tree to call it. These five are the whole of
//!     upstream's `include_HEADERS` (`src/Makefile.am:1-6`) and the six
//!     internal headers are not installed, because upstream does not install
//!     them either.
//!   * `lib/pkgconfig/libunibreak.pc`, generated by `addPkgConfig` from
//!     upstream's own `libunibreak.pc.in` field for field. `prefix` is
//!     `${pcfiledir}/../..` rather than autotools' substituted `@prefix@`, so
//!     the installed file is correct wherever `--prefix` put it.
//!   * `LICENCE` (note the British spelling), `LICENCE-UNICODE.txt` and
//!     `README.upstream.md` at the prefix root, under the names this
//!     repository preserves them under. `LICENCE` is upstream's Zlib grant
//!     verbatim; `LICENCE-UNICODE.txt` is the carried primary text of the
//!     Unicode terms that govern the seven generated tables compiled into the
//!     library and the three fixtures; and `README.upstream.md` is upstream's
//!     own README byte for byte. **This fork's `README.md` is deliberately not
//!     installed**: it documents this fork's routes, deviations and support
//!     matrix and points at files a recipient of the binary does not have, so
//!     installing it would ship a description of something the recipient does
//!     not have. Which file each of the three falls under, and the per-file
//!     exceptions upstream ships, are `NOTICE.md`'s record.
//!
//! `src/Makefile.am:53-56` also carries an `install-exec-hook` that drops a
//! `liblinebreak.a` symlink beside the archive when the static library was
//! installed, so that a consumer still using the pre-8.0 name links. That hook
//! is not reproduced here, and the reason is a capability rather than a
//! judgement: this Zig release's only install-symlink step is
//! `std/Build/Step/Compile.doAtomicSymLinks` (`Compile.zig:1869`), which
//! creates an artifact's own `libX.so.N`/`libX.so` pair and cannot be pointed
//! at an unrelated name, so the alias would have to be a second copy of the
//! archive installed under another name. That is a different artifact from
//! the one upstream installs, and inventing it would be a worse answer than
//! naming the gap.
//!
//! Published routes
//! ----------------
//! Three ways in, and what `zig build` leaves on disk:
//!
//!   * `dep.module("libunibreak")`: the Zig facade, `zig/root.zig`. This is the
//!     one registered module. It carries `link_libc`, `src/` on its include
//!     path, the translated headers as `c`, and the native library behind all
//!     three, so a dependent that adds this module needs nothing further to
//!     call the facade or to reach `linebreak.h`.
//!   * `c` on that same module: the translated headers themselves, for a caller
//!     that needs a declaration the facade does not name. It is deliberately
//!     *not* registered as a module of its own: `addModule("c")` would make
//!     `dep.module("c")` resolve and hand a dependent the same declarations
//!     without the library that satisfies them, which is a reachability a
//!     dependent cannot tell from support.
//!   * `dep.artifact("unibreak")`: the compiled native library, in whichever
//!     `-Dlinkage` selected. It is not needed to use the facade and no consumer
//!     here asks for it. The module is named `libunibreak` and the artifact
//!     `unibreak` because Zig's `binNameAlloc` prepends the platform `lib`
//!     prefix to a library's own name (`lib/std/zig.zig:156`), so the emitted
//!     file is exactly upstream's `libunibreak.a` (`src/Makefile.gcc:115`,
//!     `libunibreak.pc.in`'s `Libs: -L${libdir} -lunibreak`), which is what
//!     an installed C consumer needs and what naming the artifact
//!     `libunibreak` would not produce.
//!   * the installed native library, the five public headers, the
//!     `libunibreak.pc` and the licence terms under `zig-out/`, for a C
//!     consumer that includes the headers and links the library.
//!   * `share/licenses/libunibreak/` with `LICENCE`, `LICENCE-UNICODE.txt`,
//!     `AUTHORS`, `README.upstream.md`, `NOTICE.md`, `FORK-LICENSE.md`,
//!     `UPSTREAM.md`, `FORK-NOTES.md` and `UPSTREAM.sha256`. The zlib grant
//!     covers the code, the Unicode terms govern the tables compiled into the
//!     library, and `package.nix` checks two of these paths by name, so the
//!     directory is the contract rather than a convenience.
//!
//! `README.zig.md` states the same routes for a reader deciding what to
//! import, and `zig/root.zig` states the Zig one on the module itself.

const std = @import("std");

/// The runtime-loading build half, owned by the API role.
///
/// `createModule` builds the generated dispatch that replaces
/// `translate.createModule()` under `-Druntime`; it makes the loader-core
/// module itself and re-exports `LoadSource`/`LoadError` from it.
/// `createCoreModule` builds that same core module for the *linked* branch,
/// where there is no dispatch to carry the types and the facade's `rt` import
/// is where they come from.
///
/// The two branches must not both call `createCoreModule`. `LoadSource` and
/// `LoadError` are this SDK's public types, so they have to be the *same*
/// types in one build: a second core instance would be a second, nominally
/// distinct `LoadSource`, and `libunibreak.load(source)` would be handing the
/// facade's type to a function expecting the dispatch's. `addGraph` documents
/// the branch and is the only function that calls either of these.
const runtime_graph = @import("runtime/graph.zig");

/// `build.zig.zon` itself. `@import` of the manifest is how a build script
/// reads `.version` without a second copy of it; `spglib/build.zig:4` uses
/// the same import.
const manifest = @import("build.zig.zon");

/// `build.zig.zon .version`, parsed. The parse is the loud part: a manifest
/// whose `.version` is not a semantic version fails to configure here rather
/// than being silently compared as something else.
const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// The name a dependent writes in its dependency map, and the name of the one
/// registered module.
const module_name = "libunibreak";

/// The library's own name. Zig prepends the target's `lib` prefix to a
/// library artifact's name, so this is what makes the emitted archive
/// `libunibreak.a` on every POSIX target - upstream's own file name.
const lib_name = "unibreak";

/// The Zig facade: an allocation-free wrapper over the translated
/// `set_*breaks_*` calls. It re-exports the translated module as `c`.
const facade_source = "zig/root.zig";

/// The explicit exercise of every public facade method. `zig build check`
/// compiles it for every matrix target, which is what forces each facade body
/// to be analysed rather than merely declared.
const exercise_source = "zig/api_exercise.zig";

/// The one header this package translates. It is a fork-authored wrapper whose
/// whole job is to name the five headers upstream installs; see the file for
/// why it is a wrapper and not a copy.
const translate_header = "zig/translate.h";

/// Test root. Every public facade method is called from here as well as from
/// `zig/api_exercise.zig`, which is what makes `zig build test` a run of the
/// facade rather than of an unreferenced archive.
const test_source = "tests.zig";

/// The deterministic example program that `zig build smoke` runs.
const example_source = "smoke.zig";

/// Upstream's own version, as `configure.ac:2` states it in
/// `AC_INIT([libunibreak],[8.0],[wuyongwei@gmail.com])` and as
/// `src/unibreakbase.h:42` states it in `#define UNIBREAK_VERSION 0x0800`.
///
/// Zig's manifest requires the three-part form, so `build.zig.zon` carries
/// `8.0.0` where upstream writes `8.0`. `build` compares the manifest's
/// major.minor against this string, so the pkg-config `Version:` field, the
/// shared object's file name and the manifest cannot describe three different
/// releases. It is the version of the C library this package builds, not a
/// version of the Zig wrapper.
const upstream_version_text = "8.0";

/// The shared library's own file name and soname, from upstream's
/// `-version-info 8:0:0` (`src/Makefile.am:10`).
///
/// Libtool reads `current:revision:age`, so the library is
/// `libunibreak.so.(current-age).(age).(revision)` — `libunibreak.so.8.0.0`
/// here — and the soname a consumer's `DT_NEEDED` records is
/// `libunibreak.so.(current-age)` — `libunibreak.so.8`. Upstream states that
/// number in two independent places (`AC_INIT`'s `8.0` and this `version-info`),
/// and `build` checks that the manifest agrees with the first; the second is
/// this constant, and it is upstream's own, not a number chosen here.
///
/// `null` for the static archive, which has no soname and no versioned file
/// name.
const abi_version: std.SemanticVersion = .{ .major = 8, .minor = 0, .patch = 0 };

/// Language level for every C translation unit, pinned.
///
/// This one is load-bearing, not stylistic. `src/unibreakdef.h:65` declares
/// `ub_bsearch` as a plain `inline` function with a body, and
/// `src/unibreakdef.c:175` closes with `extern inline ... ub_bsearch(...)`:
/// C99 inline semantics. Under the C89 rule an `inline` definition emits no
/// symbol at all, so every translation unit that binary-searches a table would
/// fail to link on `ub_bsearch` - and that failure looks like a missing symbol,
/// not like a dialect problem. No upstream makefile passes a dialect flag at
/// all - `src/Makefile.gcc:89` has only `-W -Wall`, `src/Makefile.msvc:59` only
/// `/nologo /MT /W3 /EHsc /O2` - so upstream relies on the compiler default;
/// pinning `-std=c99` here is what makes the level a fact of this build rather
/// than a fact about the host's clang.
///
/// The same level applies in both linkages. There is no per-linkage flag list
/// in this file, and there is deliberately no `-fvisibility` flag in either:
/// upstream's headers declare no visibility macro, so there is nothing to
/// widen and nothing to narrow. See "Static and shared delivery" above.
///
/// `-D_DEBUG`/`-DNDEBUG` is left to the optimize mode the caller chose, exactly
/// as `src/Makefile.gcc:91-92` maps its Debug and Release configurations, so
/// `wordbreak.c:453`'s unreachable-default `assert(0)` and the three
/// `assert(*ip <= len)` in `src/unibreakdef.c` are present in Debug and
/// ReleaseSafe and gone in ReleaseFast and ReleaseSmall, which is upstream's
/// own arrangement and not something this build second-guesses.
const c_flags = [_][]const u8{"-std=c99"};

/// The core library: upstream's own `libunibreak_la_SOURCES`
/// (`src/Makefile.am:11-20`), in upstream's order.
///
/// `src/Makefile.gcc:108-110`'s `CFILES` names the same nine files, and it is
/// the list that shows why a shorter list is wrong: the six generated tables
/// that are *textually included* rather than compiled -
/// `linebreakauxdata.c` (`src/linebreak.c:59`), `wordbreakdata.c`
/// (`src/wordbreak.c:56`), `graphemebreakdata.c` (`src/graphemebreak.c:51`),
/// `indicconjunctbreakdata.c` (`src/graphemebreak.c:52`),
/// `eastasianwidthdata.c` (`src/eastasianwidthdef.c:25`) and `emojidata.c`
/// (`src/emojidef.c:33`) - do not appear in it, while `linebreakdata.c` does,
/// because `src/linebreakdef.h:233-235` declares `lb_prop_supplementary` and
/// `lb_prop_bmp` `extern` and `src/linebreakdata.c` is their only definition.
/// Compiling those six as well would be a duplicate definition of every table
/// they contain.
///
/// Files in this repository this build deliberately does not compile:
///
///   * `src/tests.c`: upstream's own conformance harness, compiled unmodified
///     as the `upstream-test` step below, exactly as `src/Makefile.am:121-126`
///     builds it (`tests_CPPFLAGS = -I$(srcdir)`,
///     `tests_LDADD = libunibreak.la`).
///   * the seven `src/generate_*.py` generators, `src/unicode_data_property.py`,
///     the two `.sed` scripts and `src/linebreakdata1.tmpl`: upstream's
///     provenance for the seven checked-in tables, not build steps. All seven
///     tables are in this repository, so nothing is fetched and no generator
///     runs here; `src/Makefile.am:62-81`'s `wget` recipes are never invoked.
///   * `tools/`: upstream's six example programs and its own `tools/test.txt`.
///     They are programs, not library sources, so no step here compiles one of
///     them, and upstream's own `Makefile.am:12` lists the directory under
///     `EXTRA_DIST` — distributed, never installed — which is upstream's reason
///     for shipping it in a tarball rather than in `$out`.
///     `tools/linebreak_test.c:20` additionally reaches outside the standard
///     headers for `<iconv.h>`, which no target in this matrix is promised.
///     The directory does travel with this package, and the two facts are
///     separate: `build.zig.zon`'s `.paths` names it whole, because the install
///     step reads one file out of it (`b.installFile("tools/test.txt", ...)`
///     below) and a package materialised from `.paths` could not install without
///     it. Carrying those bytes is not a claim that they build; of the seven,
///     this package installs exactly one, `tools/test.txt`.
///   * `src/Makefile.gcc`, `src/Makefile.msvc`, `src/Makefile.am`,
///     `configure.ac`, `bootstrap`, `autogen.sh`, `Makefile.am`, `purge` and
///     `libunibreak.pc.in`: upstream's own build system. Nothing here reads,
///     writes or executes any of it, and `addPkgConfig` reads the `.pc` template
///     field for field rather than running the tools that would fill it.
const core_sources = [_][]const u8{
    "src/unibreakbase.c",
    "src/unibreakdef.c",
    "src/linebreak.c",
    "src/linebreakdata.c",
    "src/linebreakdef.c",
    "src/eastasianwidthdef.c",
    "src/emojidef.c",
    "src/graphemebreak.c",
    "src/wordbreak.c",
};

/// Upstream's `include_HEADERS` (`src/Makefile.am:1-6`): the five headers
/// upstream installs, which are also the five this package installs and the
/// five `zig/translate.h` names.
///
/// The six internal headers are not here and are not installed: upstream does
/// not install them and its own harness (`src/tests.c:32-34`) includes only the
/// three public algorithm headers plus `test_skips.h`.
const public_headers = [_][]const u8{
    "src/unibreakbase.h",
    "src/unibreakdef.h",
    "src/linebreak.h",
    "src/graphemebreak.h",
    "src/wordbreak.h",
};

/// The directory that holds the core sources, the headers and the three
/// Unicode fixtures, and the include path every C compilation and every
/// translation below is given.
///
/// Every internal include in this tree is quoted and relative to `src/`, and the
/// generated tables are included by bare name: `src/linebreak.c:59`,
/// `src/wordbreak.c:56`, `src/graphemebreak.c:51-52`,
/// `src/eastasianwidthdef.c:25` and `src/emojidef.c:33` each pull in a table
/// source, and `src/linebreakdata.c` is a real translation unit of its own whose
/// `lb_prop_supplementary` and `lb_prop_bmp` are `extern` at
/// `src/linebreakdef.h:233-235`. One include path, given to every target, is
/// what keeps all of that resolvable.
const source_dir = "src";

/// The retained upstream default of the one macro that changes how the library
/// is compiled.
///
/// `src/graphemebreak.c:57-63` defines `UNIBREAK_LAZY_INCB` to 0 when it is not
/// already defined, with the reason in place: since Unicode 16.0 `InCB=Consonant`
/// is assigned to characters whose `Grapheme_Cluster_Break` is `Other`, so the
/// InCB lookup can no longer be skipped. It is stated on the compile line rather
/// than left to the `#ifndef` so that this build records the value it compiled
/// and nothing else can supply a different one. It is not defined on the
/// translation: no declaration in the five public headers depends on it, and
/// this build defines no macro that a header could see differently from the way
/// the core was compiled. Both linkages compile it the same way, because it is
/// a property of the sources and not of the delivery.
const lazy_incb_macro = [_][2][]const u8{
    .{ "UNIBREAK_LAZY_INCB", "0" },
};

/// Upstream's own conformance harness, unmodified.
const upstream_test_source = "src/tests.c";

/// The three runs of `src/tests.c`, in upstream's own order.
///
/// `src/Makefile.am:128-134`'s `check` target runs `./tests line`, `./tests word`
/// and `./tests grapheme`; `src/tests.c:128-156` switches on the first character
/// of `argv[1]` to pick the fixture and the opcode set, `src/tests.c:123`
/// rejects any argument count but one, and `src/tests.c:306` returns
/// `testsFailed > 0` from `main`. Three runs, each a real pass or fail on
/// upstream's own exit status, with no wrapper to interpret.
const upstream_test_selectors = [_][]const u8{ "line", "word", "grapheme" };

/// The cross-compilation matrix `check` walks when no target is named. The
/// order is the one this workspace uses everywhere; nothing is skipped, and
/// nothing here is pre-judged: if a target cannot be satisfied on the machine
/// running the gate, that is for the gate to report.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// One target's library and facade.
const Graph = struct {
    /// The compiled native library, in whichever linkage this graph resolved.
    c_lib: *std.Build.Step.Compile,
    /// The facade module, with `c` bound to the translated headers for the
    /// library this graph compiled.
    module: *std.Build.Module,
    /// The module bound to the name `c`, carried out of `addGraph` so that a
    /// program importing `c` directly gets the *same* module instance the
    /// facade's `c` is, in both branches.
    ///
    /// Under `linked` that is `translate.createModule()`. Under `-Druntime` it
    /// is the generated dispatch `runtime_graph.createModule(...)` returned, not a
    /// second translation of the same headers: two translate-c runs over the
    /// same five headers would produce two nominally distinct sets of extern
    /// struct types, and a Zig program passing one of them to a function
    /// expecting the other would not compile at all. `zig/api_exercise.zig`
    /// imports `c` in its own right, so this is not a theoretical hazard.
    c_module: *std.Build.Module,
};

/// The licence, notice and provenance records installed under
/// `share/licenses/libunibreak/`, in addition to the three `build` already
/// installs there.
///
/// `NOTICE.md`, `FORK-LICENSE.md` and `UPSTREAM.md` go to that directory from
/// the install step directly, and they are not repeated here; a second copy of
/// the same bytes at the same path would be a step that installs nothing new.
/// Everything else this package carries under terms is below.
///
/// `LICENCE` (British spelling, and the name upstream uses) is upstream's own
/// zlib text for the code. `LICENCE-UNICODE.txt` is the carried primary text
/// of the Unicode terms that govern the seven generated tables compiled into
/// the library and the three fixtures in `src/`, so it governs bytes inside
/// the archive rather than beside it. `AUTHORS` is upstream's authorship file.
/// `README.upstream.md` is upstream's README byte for byte and is the
/// attribution this fork's grant requires to travel.
/// `FORK-NOTES.md` and `UPSTREAM.sha256` are this fork's own records.
///
/// The first three of these also keep their prefix-root and
/// `share/libunibreak/` installs: those paths are upstream-facing statements
/// about what the library is and how its tables are exercised, and moving them
/// would remove an existing claim rather than add one.
const licence_records = [_][]const u8{
    "LICENCE",
    "LICENCE-UNICODE.txt",
    "AUTHORS",
    "README.upstream.md",
    "FORK-NOTES.md",
    "UPSTREAM.sha256",
};

/// The name a compiled artifact carries in this build graph.
///
/// The published graph installs `libunibreak.a`, the name an installed C
/// consumer's `-lunibreak` needs. A check graph installs nothing, so its
/// artifacts carry the target triple instead: six targets share one build
/// graph, and six steps all called "unibreak" make `--summary all` impossible to
/// read.
fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// Installs the carried licence texts and provenance records under
/// `share/licenses/libunibreak/`.
///
/// These are copies of files already in this repository, byte for byte;
/// nothing is rewritten, merged or truncated on the way out. `b.installFile`
/// takes a repository path and attaches its own step to the install step
/// (`lib/std/Build.zig:1675-1677`), so this needs no separate `dependOn` —
/// which is why the list above, and not a directory copy, is what makes the
/// install complete: a missing entry is a build failure naming the file.
fn installLicenceRecords(b: *std.Build) void {
    // `module_name`, not `lib_name`: the installed directory is named after the
    // package, and `lib_name` is the artifact stem (`unibreak`), so the
    // directory this must create is `share/licenses/libunibreak/`.
    for (licence_records) |record| {
        b.installFile(record, b.fmt("share/licenses/{s}/{s}", .{ module_name, record }));
    }
}

/// Whether this target's OS has a dynamic linker at all, and therefore
/// whether it can carry a shared object.
///
/// Windows uses its PE/COFF loader without an interpreter path.
/// Other shared targets need a dynamic linker. WASI has neither.
fn targetHasDynamicLinker(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// The refusal a caller gets when it asks for a shared object a target cannot
/// carry.
///
/// A target whose OS has no dynamic linker cannot load a shared object at all:
/// WASI is the one this package's own matrix walks, and
/// `std.Target.DynamicLinker.kind` is `.none` for it
/// (`lib/std/Target.zig:2345-2402`). **This build refuses the request. It does
/// not deliver a static archive in place of the shared object it was asked
/// for**, with a warning, or by any other route: a caller that asked for a
/// shared object and receives an archive has been given something else, and a
/// consumer that links `-lunibreak` against it would be testing a delivery the
/// build graph never claimed to produce. The refusal names the target and the
/// way out, which is `-Dlinkage=static` for that target — the delivery this
/// SDK has always produced and the one its default already selects.
///
/// The same rule reaches all three callers, so none of them can disagree:
/// `build` panics for the selected `-Dtarget`, and `addTargetCheck` installs a
/// failing step for each unsupported matrix target so that `zig build check
/// -Dlinkage=dynamic` reports the wasm32-wasi cell as refused instead of
/// quietly compiling it as something else. The six-target matrix is never
/// narrowed: the cell exists, and it says why.
fn unsupportedLinkageMessage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) []const u8 {
    return b.fmt(
        "libunibreak: -Dlinkage=dynamic was requested for {s}, whose OS has " ++
            "no dynamic linker, so it cannot carry a shared object. This build " ++
            "does not substitute a static archive for the shared object that " ++
            "was asked for; build this target with -Dlinkage=static, which is " ++
            "this SDK's default.",
        .{@tagName(target.result.os.tag)},
    );
}

/// Compiles the core library for one target: the nine translation units above
/// at the pinned C level, with `src/` on the include path for every one of
/// their quoted includes.
///
/// `linkage` is the linkage the caller asked for, used verbatim: this build
/// never delivers one kind in place of the other. What it selects is the
/// artifact and nothing else about the compilation: the same sources, the same
/// macros, the same flags. What a shared artifact adds is its own requirements
/// — the soname, position independence, and the fact that nothing may be left
/// undefined.
///
/// No generated input and no config header are involved. Upstream's autotools
/// build writes a `config.h`, and this tree has no `configure.ac` macro any
/// source tests: nothing in `src/*.c` includes `<config.h>`, so there is
/// nothing to generate per target and no way for a host's configuration to
/// reach a cross target's compile line.
///
/// `name` is the artifact name this graph installs or reports; see
/// `artifactName`.
fn addCoreLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    name: []const u8,
) *std.Build.Step.Compile {
    // A requested shared object on a target with no dynamic linker is refused
    // before a step is created, by `build` and by `addTargetCheck`, so this
    // function is never reached with a pairing it cannot deliver.
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // Upstream's own `-version-info 8:0:0` (`src/Makefile.am:10`). `null`
        // for a static archive, which has no soname and no versioned file name.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // libc, because every translation unit reaches `<string.h>` and the
            // library's whole vocabulary is memset/memcpy/strlen/strncmp/memcmp
            // through it (`src/linebreak.c:55`, `src/wordbreak.c:53`,
            // `src/graphemebreak.c:49`, `src/unibreakdef.c:35-37`). There is no
            // libm dependency: no source includes `<math.h>`.
            .link_libc = true,
            // A shared library is position-independent whether or not this says
            // so; naming it makes the requirement explicit, and it stays unset
            // for the static archive, which is the delivery this SDK has always
            // produced and which needs no relocatability. Every one of the nine
            // translation units is compiled on this one module, so there is no
            // separately built object that could miss the flag.
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;

    // No export, import or visibility macro is defined here, in either
    // linkage, because the five public headers declare none to define: see
    // "Static and shared delivery" above. That is upstream's own arrangement,
    // not an omission, and adding a decoration the headers do not have would
    // be this build inventing an ABI surface upstream never wrote.
    c_mod.addIncludePath(b.path(source_dir));
    for (lazy_incb_macro) |macro| {
        c_mod.addCMacro(macro[0], macro[1]);
    }
    for (core_sources) |source| {
        c_mod.addCSourceFile(.{
            .file = b.path(source),
            .flags = &c_flags,
        });
    }

    // Installing a header also puts it on the include path of anything that
    // links this artifact, so a C consumer of the installed library needs
    // nothing from this tree to call it. These five are the whole of upstream's
    // `include_HEADERS`, and they install flat into `include/`: the second
    // argument is the path inside the installed include tree, not the path in
    // this repository, so it is the bare name (`std.Build.Step.Compile.zig`'s
    // `addHeaderInstallationToIncludeTree`, which copies each header to
    // `dest_rel_path`).
    for (public_headers) |header| {
        c_lib.installHeader(b.path(header), std.fs.path.basename(header));
    }

    return c_lib;
}

/// Builds one target's library and facade.
///
/// `public` chooses between the package module set, which is what a dependent
/// reaches through `dep.module("libunibreak")`, and a private module. A
/// cross-target check needs the private form: modules are registered by name
/// against the whole build, so registering `libunibreak` once per matrix target
/// would leave only the last of them reachable and silently stop checking the
/// rest. The translated headers are imported rather than registered in both
/// forms; the published routes are named above.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    public: bool,
) Graph {
    const c_lib = addCoreLibrary(b, target, optimize, linkage, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // `zig/translate.h` includes the five public headers by name, and this is
    // the only header search path the translation has. Without it the
    // translation would silently bind to whatever `linebreak.h` happens to be
    // installed on the build machine and describe that library's declarations
    // rather than the ones this graph compiles (`WISDOM.md` W14).
    translate.addIncludePath(b.path(source_dir));

    const module = if (public)
        b.addModule(module_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Where the runtime-loading seam is
    // ---------------------------------
    // `runtime/graph.zig`, which the API role owns, exposes
    //
    //     pub fn createModule(
    //         b: *std.Build,
    //         translate: *std.Build.Step.TranslateC,
    //         target: std.Build.ResolvedTarget,
    //         optimize: std.builtin.OptimizeMode,
    //     ) *std.Build.Module
    //
    // and `-Druntime` substitutes that one call for `translate.createModule()`.
    // It takes the `TranslateC` step this function has already built, so the
    // generated dispatch keeps the exact translated type and constant
    // namespace rather than compiling a second copy of the native extern
    // structs and casting between two nominally distinct Zig modules: every
    // type and constant in the dispatch is re-exported from the translation it
    // was generated from, so `c.lb_opcode_t` in the facade and the declaration
    // behind the table are one type.
    //
    // `-Dlinkage` is orthogonal and keeps meaning what it means: it selects
    // which artifact this build *delivers* and installs, never which one the
    // module dispatches through. `c_lib` is built and installed either way.
    //
    // The `rt` import is for the linked branch only, and the reason is the
    // nominal type rather than the code. `runtime_graph.createModule` creates the one
    // core-module instance the generated dispatch uses and re-exports
    // `LoadSource`/`LoadError` from it; a second instance created here for the
    // facade would be a *different* `LoadSource`, and `libunibreak.load(source)`
    // would be handing the facade's type to the dispatch's. One instance per
    // build, no more. In a linked build there is no dispatch, so the facade's
    // own `rt` import is where those two public types come from;
    // `zig/root.zig` picks between the two with a comptime branch on
    // `runtime_loaded`, so the module a configuration does not need is never
    // resolved and never compiled.
    //
    // The `c_module` this function returns is whichever of the two the branch
    // chose, so a program importing `c` in its own right — `api_exercise.zig`
    // does — gets that same instance and not a second translation of the same
    // five headers.
    const c_module: *std.Build.Module = if (runtime_loaded)
        // A loaded provider must arrive through the platform loader, so the
        // link line names nothing. Linking the archive as well would make the
        // linker resolve the same symbols statically and the runtime route
        // would quietly be a linked one. The artifact itself is still built and
        // installed above, because delivery and dispatch are separate
        // questions: the whole point of the mode is that a caller may name a
        // provider this tree did not build.
        runtime_graph.createModule(b, translate, target, optimize)
    else blk: {
        const translated = translate.createModule();
        module.addImport("rt", runtime_graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
        break :blk translated;
    };

    // The translated headers are imported, never registered. `addModule("c")`
    // would make `dep.module("c")` resolve and hand a dependent the same
    // declarations without the library that satisfies them; `c` on the facade
    // is the supported way in and carries the facade's own linkage.
    module.addImport("c", c_module);
    // The same include path as the archive's own module, on the module a
    // dependent actually imports, so a dependent that compiles its own C
    // against this package finds the same headers the core was compiled with.
    module.addIncludePath(b.path(source_dir));

    return .{ .c_lib = c_lib, .module = module, .c_module = c_module };
}

/// A Zig program or test root that imports the published facade module, and -
/// where `with_c` is set - the translated headers as well.
///
/// `link_libc` is stated on every one of them even though the facade carries
/// it: a dependent states its own, and this build should fail here if the
/// facade ever stopped bringing libc along. The library is not linked a second
/// time: it arrives with the imported facade module, which is what makes that
/// module self-contained, and a redundant `linkLibrary` here would put the same
/// artifact on the link line twice - and under `-Druntime`, whose whole point
/// is that nothing is linked, would defeat the mode.
fn programModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    source: []const u8,
    with_c: bool,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport(module_name, graph.module);
    if (with_c) mod.addImport("c", graph.c_module);
    return mod;
}

/// Builds upstream's own `src/tests.c`, unmodified, for one target.
///
/// It is a C program, so it needs `src/` on its include path for
/// `#include "linebreak.h"` (`src/tests.c:32-34`) and for its own
/// `#include "test_skips.h"` (`src/tests.c:36`), and the library behind it for
/// the library (`src/Makefile.am:125`).
fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // libc, because the harness includes <stdlib.h>, <stdio.h>,
        // <string.h> and <time.h> and prints its own report.
        .link_libc = true,
    });
    mod.addIncludePath(b.path(source_dir));
    mod.addCSourceFile(.{
        .file = b.path(upstream_test_source),
        .flags = &c_flags,
    });
    mod.linkLibrary(graph.c_lib);
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Compiles the full graph, the exercise, the tests, the example and upstream's
/// own harness for one matrix target, and attaches all of them to `step`.
///
/// Building the test binary and the exercise is what makes this a check of the
/// facade rather than of an unreferenced archive: Zig analyses a function body
/// only when something calls it, `tests.zig` and `zig/api_exercise.zig` call
/// every public facade method, and so compiling them for a target analyses all
/// of them for that target. The full C source is compiled by the same graph.
/// Nothing is run here, so every result this step produces is compile evidence
/// and not a claim that a cross-built binary executed - which is why the
/// upstream harness appears here as a compile and not as a run.
///
/// `linkage` and `runtime_loaded` are passed through rather than read from the
/// top-level options, so a check graph is exactly the published graph minus the
/// module registration. That is what makes `zig build check -Dlinkage=dynamic`
/// and `zig build check -Druntime=true` gates of the configurations a consumer
/// would really build rather than of a static linked approximation.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // The triple names the cross artifacts. Six targets in one build graph
    // otherwise produce six steps called "unibreak", which makes `--summary
    // all` useless for telling them apart.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // A matrix target that cannot carry the requested linkage is refused as
    // its own step, not skipped and not quietly compiled as something else.
    // The cell still exists, so `zig build check -Dlinkage=dynamic` still walks
    // all six targets and still reports six results; the wasm32-wasi one simply
    // says why it cannot be built instead of turning into a silent fallback
    // that a reader would take for coverage.
    if (linkage == .dynamic and !targetHasDynamicLinker(cross_target)) {
        const refusal = std.Build.Step.Fail.create(
            b,
            b.fmt("{s}\n  target: {s}", .{
                unsupportedLinkageMessage(b, cross_target),
                triple,
            }),
        );
        refusal.step.name = b.fmt("check {s}: unsupported -Dlinkage=dynamic", .{triple});
        step.dependOn(&refusal.step);
        return;
    }

    const graph = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libunibreak-exercise-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, exercise_source, true),
    }).step);

    step.dependOn(&b.addTest(.{
        .name = b.fmt("libunibreak-tests-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, test_source, false),
    }).step);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libunibreak-smoke-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, example_source, false),
    }).step);

    step.dependOn(&addUpstreamTest(
        b,
        cross_target,
        optimize,
        graph,
        b.fmt("libunibreak-upstream-tests-{s}", .{triple}),
    ).step);
}

/// Writes `lib/pkgconfig/libunibreak.pc` and installs it.
///
/// Every field is upstream's, from `libunibreak.pc.in`, so a consumer that
/// already asks pkg-config about a libunibreak built by autotools gets the same
/// answer here. The first line is upstream's own `libunibreak:` variable
/// declaration and is kept, because dropping it would be a second, quieter
/// statement about the file. Two things differ from upstream's *configured*
/// file, both deliberately:
///
///   * `prefix` is `${pcfiledir}/../..` instead of autotools' substituted
///     `@prefix@`. This graph does not know where `--prefix` will point when it
///     writes the file, and configure does know its own prefix at configure time
///     because configure *is* the build system. pkg-config resolves
///     `${pcfiledir}` against the `.pc` file it found, so the installed file is
///     correct wherever the prefix landed, including a Nix store path that is
///     only known at build time.
///   * `Version:` is formatted from `build.zig.zon .version`, which `build` has
///     already checked against upstream's own `8.0`. autotools substitutes
///     `@VERSION@` from the same `AC_INIT`; here the three-part string Zig's
///     manifest requires is used instead, so the manifest, this file and the
///     shared object's file name cannot name three different releases. The one
///     difference from a configured file is a trailing `.0`.
///
/// `Libs:` and `Cflags:` are upstream's literal lines
/// (`libunibreak.pc.in:10-11`) in both variants, and neither changes with
/// linkage. That is not an omission: the library *name* does not change with
/// linkage, so a consumer asks for `-lunibreak` and the linker resolves it to
/// `libunibreak.a` or, through the `libunibreak.so` symlink, to the shared
/// object; and there is no import macro to put in `Cflags` because these
/// headers declare none. Adding `-DUNIBREAK_DLL` here would be inventing a
/// macro that does not exist in `src/`.
///
/// `libdir=${prefix}/lib` and `includedir=${prefix}/include` are this build's
/// own install layout, which is `Build.zig:737-739`'s default and the layout
/// upstream's autotools tree produces too. A caller who overrides `--libdir`
/// would put the library somewhere the generated file does not name, and that
/// is a stated assumption rather than a silent one: `libunibreak.pc.in` has the
/// same shape, because `@libdir@` is whatever configure was told too.
///
/// There is deliberately no `Libs.private:` either: upstream's template has no
/// such field, and the library's only dependency is libc, which every consumer
/// already links.
fn addPkgConfig(b: *std.Build) void {
    const files = b.addWriteFiles();
    const pc = b.addInstallFileWithDir(
        files.add("libunibreak.pc", b.fmt(
            \\# Generated by build.zig from upstream's libunibreak.pc.in.
            \\# Field names and order are upstream's; build.zig's addPkgConfig
            \\# says which two values differ from an autotools-configured file
            \\# and why.
            \\libunibreak:
            \\prefix=${{pcfiledir}}/../..
            \\exec_prefix=${{prefix}}
            \\libdir=${{prefix}}/lib
            \\includedir=${{prefix}}/include
            \\
            \\Name: libunibreak
            \\Description: Library to implement Unicode algorithms for line and word breaking
            \\Version: {f}
            \\Libs: -L"${{libdir}}" -lunibreak
            \\Cflags: -I"${{includedir}}"
            \\
        , .{manifest_version})),
        .lib,
        "pkgconfig/libunibreak.pc",
    );
    // `addInstallFileWithDir` only *creates* the step: it does not put it on
    // the install step, so without this the file would be written to the cache
    // and never reach `zig-out`, and `zig build` would exit zero having installed
    // no metadata. `Build.installFile` (`Build.zig:1675-1677`) is the one that
    // wires the dependency, and this is the same statement written out because
    // the source here is generated rather than a file in this repository.
    b.getInstallStep().dependOn(&pc.step);
}

/// Runs the consumer package as its own `zig build` in `consumer/`.
///
/// The consumer is a separate package on purpose: a manifest dependency here
/// would close a cycle, because its manifest points back at this package by
/// path. Running it as a separate build is what makes the proof real - that a
/// package which only writes `b.dependency("libunibreak", ...)` and
/// `dep.module("libunibreak")` gets a working, correctly linked library, with
/// the artifact and libc arriving through the module and nothing else.
///
/// `linkage` and `runtime_loaded` are forwarded on the command line, not left
/// to the consumer's own defaults, so `zig build consumer -Dlinkage=dynamic`
/// exercises the shared delivery from outside the package and
/// `zig build consumer -Druntime=true` exercises the runtime dispatch the same
/// way. A consumer that could only ever see the default configuration would not
/// be evidence for either.
///
/// The caller's own arguments travel behind `--`, for the same reason the two
/// above are written out rather than left to the consumer's defaults: what the
/// caller asked this build to check is the whole of what it reports.
///
/// Run, or only install. `hostCanExecute` below asks whether this host can
/// execute the selected target, and an executor counts only when the build
/// runner was told to use one: `-fqemu`, `-fwasmtime`, `-fwine`, `-fdarling`.
/// A target with no enabled executor installs, which is compile evidence only.
fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const query = target.query;
    // `addArg` copies each argument, so these temporaries can go right after.
    const triple = query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const cpu = query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    // `b.graph.zig_exe` is the compiler running this build script, so the
    // nested build is the same toolchain rather than whatever is on PATH.
    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    run.setCwd(b.path("consumer"));
    run.addArg(if (hostCanExecute(b, target)) "run" else "install");
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    // The model and its feature set, because the triple does not carry them.
    // `serializeCpu` writes `native` for a query that named no CPU and
    // `baseline` for a cross query that named none, and the name of an explicit
    // model followed by its added and subtracted features
    // (`lib/std/Target/Query.zig:490-527`), so the nested build compiles the
    // same consumer this graph would have compiled. The consumer's own
    // `standardTargetOptions` declares `cpu` beside `target` and hands both to
    // `b.dependency`, so this is that build's own selection and not a default.
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    run.addArg(b.fmt("-Druntime={}", .{runtime_loaded}));
    // Forward the selected executor and its dynamic-linker support.
    if (b.enable_darling) run.addArg("-fdarling");
    if (b.enable_qemu) run.addArg("-fqemu");
    if (b.enable_rosetta) run.addArg("-frosetta");
    if (b.enable_wasmtime) run.addArg("-fwasmtime");
    if (b.enable_wine) run.addArg("-fwine");
    if (b.libc_runtimes_dir) |runtimes| run.addArgs(&.{ "--libc-runtimes", runtimes });
    // The nested build carries this workspace's job count in its own command
    // line, for the reason every `zig build` entry in `devenv.nix` writes one:
    // nothing can append a `-j` to a `Run` step's command, so a nested build
    // left to derive its own width takes `cpu_count - 1`
    // (`std/Io/Threaded.zig:1639`) instead, and the consumer this step proves
    // then compiles at a different width from the build that asked for it --
    // and at a different width again on whichever machine runs the gate.
    run.addArg("-j8");
    // `--summary all`, two arguments for the same reason `--cache-dir` below is
    // two: the build runner documents it as `--summary [mode]`
    // (`lib/compiler/build_runner.zig:1639`) and reads the mode as the next
    // argument, with `all` one of five enumerated spellings (`:1640-1644`).
    // Left off, the nested build reports `.failures`, which prints nothing when
    // nothing failed -- so on a passing consumer the gate's own output would
    // show no steps at all, and the run this step exists to perform would be
    // invisible in the log that has to carry it.
    run.addArgs(&.{ "--summary", "all" });
    // A null `path` means "the current directory", and the working directory
    // is already the consumer package, so the default is right. Two arguments,
    // not one `--cache-dir=...`: that is the form the build system emits to
    // the compiler itself, not to the build runner.
    if (b.cache_root.path) |cache| {
        run.addArg("--cache-dir");
        run.addArg(b.fmt("{s}/consumer", .{cache}));
    }
    // The global cache travels by its own path, with no `/consumer`
    // subdirectory, and that asymmetry with the local cache above is the whole
    // point rather than an oversight.  The local cache holds this graph's
    // manifest directory and is locked for the life of the process holding it,
    // so two graphs are given two of them; the global cache holds
    // content-addressed package directories keyed by hash, which is what is
    // meant to be shared between builds, and the compiler forwards it verbatim
    // from a build script rather than deriving one
    // (`lib/std/Build/Step/Compile.zig:1477-1480`, and again
    // `lib/std/Build/Step/TranslateC.zig:179-180`).  Two arguments, and the
    // same spelling as the local pair
    // (`lib/compiler/build_runner.zig:1675`).  The build runner populates this
    // path unconditionally (`:53-54`, `:73-76`, `:89`), so a
    // `--global-cache-dir` the caller named here is the directory the nested
    // build then uses, instead of the nested build resolving one of its own
    // outside this workspace's approved root.
    if (b.graph.global_cache_root.path) |global_cache| {
        run.addArg("--global-cache-dir");
        run.addArg(global_cache);
    }
    // The install prefix travels too, and only when the caller named one. The
    // default is this build's `<build root>/zig-out`, which is also what the
    // nested build would resolve for itself under `consumer/`, so forwarding
    // the default would say nothing the caller chose. A non-default prefix is
    // forwarded, and made absolute first: a relative `--prefix` resolves
    // against the nested working directory, which is `consumer/` rather than
    // this build's root. `DESTDIR` needs no forwarding, because the nested
    // build inherits the environment this one ran with.
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    if (!std.mem.eql(u8, b.install_prefix, default_prefix)) {
        const prefix = if (std.fs.path.isAbsolute(b.install_prefix))
            b.install_prefix
        else
            b.pathJoin(&.{ b.graph.cache.cwd, b.install_prefix });
        run.addArg("--prefix");
        run.addArg(prefix);
    }
    // The caller's own arguments, last and behind `--`.  `zig build consumer --
    // --provider <path>` collects them in `b.args`, and this package's consumer
    // program reads `--provider` from argv
    // (`consumer/src/main.zig:55-77`), so an argument the outer command line
    // accepts and the nested build never sees is a `consumer` run reporting a
    // narrower check than the one it was asked for.  Every argument above is
    // this package's own bookkeeping with the nested build; an argument the
    // caller typed is forwarded verbatim or not at all, and this `--` has to
    // follow all of them because it ends the nested build's option parsing.
    if (b.args) |args| {
        run.addArg("--");
        run.addArgs(args);
    }
    // The nested build is the step's only observable effect.
    run.has_side_effects = true;
    return run;
}

/// True when this build can execute `target`'s binaries: the question
/// `std.Build.Step.Run` asks about the artifact it is about to spawn, asked
/// here about the resolved target with the same options `Run` fills in.
fn hostCanExecute(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    const host = &b.graph.host.result;
    const candidate = &target.result;
    const options: std.zig.system.GetExternalExecutorOptions = .{
        .allow_darling = b.enable_darling,
        .allow_qemu = b.enable_qemu,
        .allow_wasmtime = b.enable_wasmtime,
        .allow_wine = b.enable_wine,
        // QEMU reaches a foreign dynamic linker only with `--libc-runtimes`.
        .qemu_fixes_dl = candidate.isGnuLibC() and b.libc_runtimes_dir != null,
        .link_libc = true,
    };
    return switch (std.zig.system.getExternalExecutor(b.graph.io, host, candidate, options)) {
        .native, .rosetta => true,
        // Without one, `Run` fails a cross GNU-libc target rather than skipping
        // it, so that case answers no.
        .qemu => !candidate.isGnuLibC() or b.libc_runtimes_dir != null,
        .wine, .wasmtime, .darling => true,
        .bad_dl, .bad_os_or_cpu => false,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The linkage as asked for. This build delivers exactly that or refuses;
    // it never answers `dynamic` with a static archive, and it never answers
    // `static` with a shared object. The refusal for a target whose OS has no
    // dynamic linker is `unsupportedLinkageMessage`, and it is enforced once
    // here for the selected `-Dtarget` and once per matrix target in
    // `addTargetCheck`, so no path reaches `addCoreLibrary` with a pairing it
    // cannot deliver.
    const linkage_option = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and " ++
            "what this package has always produced) or as a real shared object " ++
            "with upstream's own soname libunibreak.so.8, from its libtool " ++
            "-version-info 8:0:0. This selects the delivery and never the " ++
            "dispatch: the same C is compiled either way, and -Druntime is " ++
            "independent of it. Requesting a shared object for a target whose " ++
            "OS has no dynamic linker is refused, not answered with an archive.",
    );
    const linkage: std.builtin.LinkMode = linkage_option orelse .static;
    // The refusal, for the selected target. A `-Dtarget` whose OS has no
    // dynamic linker cannot carry the shared object that was asked for, and
    // this build does not hand back an archive instead: it stops here, before
    // any step exists, with a message that names the target and the way out.
    // The default `static` is unaffected, so `-Dtarget=wasm32-wasi` on its own
    // still builds the archive that target can carry.
    if (linkage == .dynamic and !targetHasDynamicLinker(target)) {
        @panic(unsupportedLinkageMessage(b, target));
    }

    // `-Druntime` selects the *dispatch*, and it is orthogonal to
    // `-Dlinkage`: the option says which artifact this build delivers and
    // installs, this one says whether the facade calls it through a link line
    // or through a table an explicit `load` fills. Under `-Druntime` nothing is
    // linked into the module at all, so a caller may name a provider this tree
    // did not build -- and the artifact is still built and installed, so a
    // caller may equally name the one it did.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated header and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, " ++
            "and the module links no archive. Independent of -Dlinkage, which " ++
            "still decides which artifact this build delivers and installs. " ++
            "Default off, and a linked build is unchanged in every respect.",
    ) orelse false;

    // `build.zig.zon .version`, the `Version:` field of `libunibreak.pc` and the
    // version this build documents in three other places are one fact. Zig's
    // manifest requires the three-part form where upstream's `AC_INIT` states
    // the two-part `8.0`, so the comparison is on major.minor: it catches a
    // manifest edited without the source it describes — the failure mode
    // `spglib/build.zig:104-106` already guards against in this workspace —
    // without pretending upstream wrote a patch component it did not.
    const manifest_major_minor = b.fmt("{d}.{d}", .{ manifest_version.major, manifest_version.minor });
    if (!std.mem.eql(u8, manifest_major_minor, upstream_version_text)) {
        @panic("build.zig.zon .version no longer matches the version read out " ++
            "of configure.ac and src/unibreakbase.h; see UPSTREAM.md");
    }

    const graph = addGraph(b, target, optimize, linkage, runtime_loaded, true);

    // The installed C library in whichever `-Dlinkage` selected, its five
    // public headers (through `installHeader` above), and the metadata and
    // terms that cover them: a private repository removes no licence
    // obligation.
    //
    // The pkg-config file is not optional. A library with no `-lunibreak` to
    // point at is a source drop, and this is the one file that gives an
    // installed C consumer a way to find the headers and the library without
    // being told where `--prefix` landed.
    b.installArtifact(graph.c_lib);
    addPkgConfig(b);
    //
    // `LICENCE` (note the British spelling) and `LICENCE-UNICODE.txt` are
    // upstream's own files, installed unmodified and not rewritten under the
    // names this repository preserves them under.
    // `LICENCE-UNICODE.txt` is the carried primary text of the Unicode terms
    // that govern the seven generated tables inside this library and the three
    // fixtures in `src/`; it is installed beside them because those tables are
    // inside the thing a consumer receives. `README.upstream.md` is upstream's
    // own README, byte for byte: it is what states what the library is, and
    // this fork's own README is not installed because it documents this fork
    // and not what the recipient received. Which file each of those falls
    // under, and the per-file exceptions upstream ships, are this fork's
    // `NOTICE.md`.
    b.installFile("LICENCE", "LICENCE");
    b.installFile("LICENCE-UNICODE.txt", "LICENCE-UNICODE.txt");
    b.installFile("README.upstream.md", "README.upstream.md");
    b.installFile("NOTICE.md", "share/licenses/libunibreak/NOTICE.md");
    b.installFile("FORK-LICENSE.md", "share/licenses/libunibreak/FORK-LICENSE.md");
    b.installFile("UPSTREAM.md", "share/licenses/libunibreak/UPSTREAM.md");
    b.installFile("src/LineBreakTest.txt", "share/libunibreak/LineBreakTest.txt");
    b.installFile("src/WordBreakTest.txt", "share/libunibreak/WordBreakTest.txt");
    b.installFile("src/GraphemeBreakTest.txt", "share/libunibreak/GraphemeBreakTest.txt");
    b.installFile("tools/test.txt", "share/libunibreak/test.txt");

    // The rest of the same obligation, at the place terms live. The three
    // records above already name `share/licenses/libunibreak/`; this completes
    // that directory with upstream's own texts and the two fork records that
    // were not in it, so a recipient who installs only the prefix has the
    // zlib grant, the Unicode terms, the authorship record and the pin
    // without having to read a README to find them.
    installLicenceRecords(b);

    // `zig build` also compiles the example. The example is the cheapest thing
    // that proves the facade, the translated headers and the C library agree on
    // types, symbols and link-time dependencies. It is compiled, not installed:
    // it is a proof, not a deliverable.
    const example = b.addExecutable(.{
        .name = "libunibreak-smoke",
        .root_module = programModule(b, target, optimize, graph, example_source, false),
    });
    b.getInstallStep().dependOn(&example.step);

    // A run artifact already depends on building the executable, which depends
    // on compiling the C and linking the facade. `zig build smoke` deliberately
    // does not depend on the install step: installing is `zig build`'s job and
    // conflating the two would make a smoke run depend on the install layout.
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    if (b.args) |args| run_example.addArgs(args);
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    // The test root is `tests.zig`, which names the test blocks; a root that
    // only re-exported them would discover no tests and still exit zero.
    // `addRunArtifact` is used rather than a plain compile so that this is a
    // real runnable test step for whatever `-Dtarget` names: a foreign target
    // is left to whichever executor the cross-test harness detects, and this
    // build does not decide that.
    const unit_tests = b.addTest(.{
        .name = "libunibreak-tests",
        .root_module = programModule(b, target, optimize, graph, test_source, false),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    const test_step = b.step("test", "Run the facade tests and every API operation");
    test_step.dependOn(&run_tests.step);

    // The exercise instantiates every method in native and cross-target builds.
    const exercise = b.addExecutable(.{
        .name = "libunibreak-exercise",
        .root_module = programModule(b, target, optimize, graph, exercise_source, true),
    });
    const run_exercise = b.addRunArtifact(exercise);
    run_exercise.has_side_effects = true;
    b.getInstallStep().dependOn(&exercise.step);
    test_step.dependOn(&run_exercise.step);
    b.step("exercise", "Run the API exercise: every public facade method once").dependOn(&run_exercise.step);

    // Upstream's own conformance harness, built and run three times against the
    // three checked-in Unicode fixtures. The working directory is `src/`,
    // which is where `LineBreakTest.txt`, `WordBreakTest.txt` and
    // `GraphemeBreakTest.txt` actually are: `src/tests.c:131,139,147` opens them
    // by bare name, upstream's own `check` target satisfies that with
    // symlinks (`src/Makefile.am:129-131`), and this build does it by running
    // the program where the files already are. No copy, no symlink, no
    // fixture rewriting, and every fixture byte is upstream's.
    //
    // The harness is C and links `graph.c_lib`, so it reaches whichever
    // artifact `-Dlinkage` selected: the same upstream parser against the same
    // three fixtures is the check that the shared object exports what the
    // archive exports.
    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own unmodified src/tests.c against the three " ++
            "Unicode fixtures in src/",
    );
    const upstream_tests = addUpstreamTest(b, target, optimize, graph, "libunibreak-upstream-tests");
    for (upstream_test_selectors) |selector| {
        const run = b.addRunArtifact(upstream_tests);
        run.setName(b.fmt("src/tests.c {s}", .{selector}));
        run.addArg(selector);
        run.setCwd(b.path(source_dir));
        // The run reads three megabytes of fixture and prints the pass count;
        // there is nothing here whose up-to-dateness is worth caching, and the
        // run itself is the result.
        run.has_side_effects = true;
        upstream_step.dependOn(&run.step);
    }

    // Built for every target; run only where this host can execute it.
    b.step("consumer", "Build the consumer/ package for the selected target, and run it when this host can execute it").dependOn(&runConsumer(b, target, optimize, linkage, runtime_loaded).step);

    // The cross target gate. Compiling the exercise, the tests, the example and
    // upstream's own harness for each target is what makes this a check of the
    // facade rather than of an unreferenced archive, and `addTargetCheck` says
    // why. Nothing runs here.
    const check_step = b.step(
        "check",
        "Compile the C core, the facade, the API exercise, the tests, the " ++
            "example and upstream's own C harness for the six-target matrix " ++
            "without running any of them",
    );
    if (!target.query.isNative()) {
        addTargetCheck(b, check_step, target.query, optimize, linkage, runtime_loaded);
    } else {
        for (check_targets) |query| {
            addTargetCheck(b, check_step, query, optimize, linkage, runtime_loaded);
        }
    }

    // Configure-time lines, not gate results: what this build graph compiled,
    // where its include path points, and in which shape it delivers. They are
    // printed whether or not any step runs, and they say nothing about whether
    // the results were executed.
    std.debug.print(
        "libunibreak: {d} core translation units from {s}/, C99, UNIBREAK_LAZY_INCB={s}, {d} public headers, {s}\n",
        .{
            core_sources.len,
            source_dir,
            lazy_incb_macro[0][1],
            public_headers.len,
            switch (linkage) {
                .static => "static archive (default)",
                .dynamic => b.fmt("shared object, soname libunibreak.so.{d}", .{abi_version.major}),
            },
        },
    );
    if (runtime_loaded) {
        // Dispatch is a separate fact from delivery, and a runtime-loaded build
        // links nothing into the module: the caller names a provider with an
        // explicit `load(source)` and the symbols arrive through the platform
        // loader. Printing it here is what keeps "the library is still built and
        // installed" from reading as "the module links it".
        std.debug.print(
            "libunibreak: runtime-loaded dispatch (-Druntime=true); no library " ++
                "is linked into the module, and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
}
