/* The headers this package translates.
 *
 * `zig build` runs translate-c over this file, and the translation becomes the
 * `c` module that the Zig facade (`zig/root.zig`) imports.  Its whole job is to
 * name the headers that describe the library this build actually compiles: the
 * five public headers upstream installs from `src/Makefile.am`
 * (`include_HEADERS`), byte for byte, in this repository.
 *
 * Which headers this resolves to
 * ------------------------------
 * By the include path, not by a macro.  Each `#include` below is an ordinary
 * search: this file's own directory, then the `-I` paths the build adds, then
 * the system directories.  There is no libunibreak header beside this file,
 * and `build.zig` adds `src/` to the translation in every mode, so these
 * always name the pinned `src/` headers of this repository - never a header
 * that happens to be installed on the build machine.  This build has no
 * system-library mode: the contract for this wave keeps the source pin and the
 * bounded contracts identical in every mode, so the headers that are
 * translated and the library that is linked cannot disagree
 * (`WISDOM.md` W14).
 *
 * Why a wrapper and not a copy of the headers
 * -------------------------------------------
 * These five files are the whole public C API of the library: every exported
 * function is declared in one of them, and none declares anything the others
 * do not.  Re-declaring any of it here would create a second, hand-maintained
 * copy of an ABI that the shipped headers already state exactly, and the two
 * could drift apart silently.  Nothing is re-declared here.
 *
 * The order below is upstream's own `include_HEADERS` order
 * (`src/Makefile.am:1-6`), which is also the order in which the headers depend
 * on one another: `unibreakdef.h:40` and every other non-base header include
 * `unibreakbase.h`, which is why it comes first.
 *
 * What is deliberately not included
 * ---------------------------------
 * The six internal headers (`linebreakdef.h`, `eastasianwidthdef.h`,
 * `emojidef.h`, `indicconjunctbreakdef.h`, `graphemebreakdef.h`,
 * `wordbreakdef.h`) and the seven generated data tables are not public API:
 * upstream's `include_HEADERS` names exactly the five files below and does not
 * install the others, and `src/tests.c` - upstream's own harness, which this
 * package compiles unmodified as `upstream-test` - includes only the three
 * public algorithm headers plus its own `test_skips.h`.  Translating an
 * internal header would publish a declaration no installed consumer can reach
 * and that upstream itself treats as private.
 *
 * Macros
 * ------
 * None are defined here or on the translation.  `UNIBREAK_LAZY_INCB`
 * (`src/graphemebreak.c:57-63`) is the one macro that changes how the library
 * is compiled, it is compiled with upstream's own default of 0, and no
 * declaration in these five headers depends on it - the build states it on the
 * C compile line for the core and says why there.
 *
 * One declaration is not an ordinary extern, and a caller should know it
 * ------------------------------------------------------------------------
 * `src/unibreakdef.h:65` declares `ub_bsearch` as a C99 `inline` function
 * *with a body*; `src/unibreakdef.c:175` supplies the external definition with
 * `extern inline`.  So the header itself gives a translator something with a
 * body to work from, and the translated module exposes `ub_bsearch` as a Zig
 * function rather than as an `extern` one - it is the header's own definition
 * that the translation sees, not the library's.  Everything else these five
 * headers declare is an ordinary function declaration and arrives as an
 * `extern fn` backed by the compiled archive.  Nothing in this package calls
 * `ub_bsearch` through the translated module: it is an internal table search
 * that the core's own translation units use, and the facade's raw C route is
 * for the exported API.  The C99 dialect is pinned on the core's compile line
 * in `build.zig`, because under the C89 rule that `inline` definition would
 * emit no symbol at all.
 *
 * This file is fork-authored and asserts no licence.  It grants nothing; the
 * terms that cover the compiled library are upstream's `LICENCE` and the
 * Unicode terms that travel with the generated tables.
 */

#ifndef LIBUNIBREAK_TRANSLATE_H
#define LIBUNIBREAK_TRANSLATE_H

#include <unibreakbase.h>
#include <unibreakdef.h>
#include <linebreak.h>
#include <graphemebreak.h>
#include <wordbreak.h>

#endif /* LIBUNIBREAK_TRANSLATE_H */