# NOTICE

## Attribution

libunibreak was created by Wu Yongwei. Wu maintains the library; Tom Hacohen added word breaking; Petr Filipsky contributed incremental line breaking; Andreas Röver added grapheme breaking. The four undated copyright lines in upstream's `LICENCE` are:

```
Copyright (C) Wu Yongwei <wuyongwei at gmail dot com>
Copyright (C) Tom Hacohen <tom at stosb dot com>
Copyright (C) Petr Filipsky <philodej at gmail dot com>
Copyright (C) Andreas RM-CM-6ver <roever at users dot sf dot net>
```

`LICENCE` is the upstream Zlib/libpng text. Its original spelling and text are retained. The last copyright spelling is upstream's transliteration of Andreas Röver; `AUTHORS` names the contributor.

## Licence scope

| Paths | Terms | Record or exception |
|---|---|---|
| Upstream C sources and headers, build files, documentation, generators, test harness and tools, except the Unicode files below | Zlib/libpng | Upstream's `LICENCE`; files without in-file notices remain under this tree-level grant. |
| `src/linebreakdata.c`, `src/linebreakauxdata.c`, `src/wordbreakdata.c`, `src/graphemebreakdata.c`, `src/indicconjunctbreakdata.c`, `src/eastasianwidthdata.c`, `src/emojidata.c`, `src/LineBreakTest.txt`, `src/WordBreakTest.txt`, `src/GraphemeBreakTest.txt` | Unicode License v3; not covered by upstream's Zlib grant | The three fixtures carry Unicode's notice; complete terms are in `LICENCE-UNICODE.txt`. |
| `tools/linebreak_test.c` | Its own separate, broader grant | The grant applies to this file only and is preserved below. |
| Fork-authored files listed in `FORK-LICENSE.md` | Zlib grant stated there | `runtime/graph.zig` and `runtime/library.zig` carry MIT SPDX identifiers; `FORK-LICENSE.md` records but does not resolve this mismatch. |
| `LICENCE-UNICODE.txt` | Unicode's own text, not a grant by this fork | Carried unchanged from `https://www.unicode.org/license.txt`. |
| `.gitignore` | Upstream file with a fork-added ignore block | Not byte-identical to upstream and omitted from `.paths` and `UPSTREAM.sha256`. |

## Upstream copyright lines

The following 20 upstream source files carry the Zlib/libpng header. Copyright lines are retained as written in those files.

| File | Copyright line(s) |
|---|---|
| `src/eastasianwidthdef.c` | `Copyright (C) 2024 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/eastasianwidthdef.h` | `Copyright (C) 2024 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/emojidef.c` | `Copyright (C) 2018 Andreas Röver <roever at users dot sf dot net>` |
| `src/emojidef.h` | `Copyright (C) 2018 Andreas Röver <roever at users dot sf dot net>` |
| `src/graphemebreak.c` | `Copyright (C) 2016-2019 Andreas Röver <roever at users dot sf dot net>`; `Copyright (C) 2024-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/graphemebreak.h` | `Copyright (C) 2016-2026 Andreas Röver <roever at users dot sf dot net>` |
| `src/graphemebreakdef.h` | `Copyright (C) 2016-2026 Andreas Röver <roever at users dot sf dot net>` |
| `src/indicconjunctbreakdef.h` | `Copyright (C) 2024 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/linebreak.c` | `Copyright (C) 2008-2026 Wu Yongwei <wuyongwei at gmail dot com>`; `Copyright (C) 2013 Petr Filipsky <philodej at gmail dot com>` |
| `src/linebreak.h` | `Copyright (C) 2008-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/linebreakdef.c` | `Copyright (C) 2008-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/linebreakdef.h` | `Copyright (C) 2008-2026 Wu Yongwei <wuyongwei at gmail dot com>`; `Copyright (C) 2013 Petr Filipsky <philodej at gmail dot com>` |
| `src/tests.c` | `Copyright (C) 2016 Tom Hacohen <tom at stosb dot com>`; `Copyright (C) 2016 Andreas Röver <roever at users dot sf dot net>`; `Copyright (C) 2024-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/unibreakbase.c` | `Copyright (C) 2015-2018 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/unibreakbase.h` | `Copyright (C) 2015-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/unibreakdef.c` | `Copyright (C) 2015-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/unibreakdef.h` | `Copyright (C) 2015-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/wordbreak.c` | `Copyright (C) 2013-2019 Tom Hacohen <tom at stosb dot com>`; `Copyright (C) 2018-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/wordbreak.h` | `Copyright (C) 2013-2019 Tom Hacohen <tom at stosb dot com>`; `Copyright (C) 2018-2026 Wu Yongwei <wuyongwei at gmail dot com>` |
| `src/wordbreakdef.h` | `Copyright (C) 2013-2019 Tom Hacohen <tom at stosb dot com>`; `Copyright (C) 2018-2026 Wu Yongwei <wuyongwei at gmail dot com>` |

## Unicode material

The seven generated tables and three fixtures listed above are Unicode, Inc. material, distributed unmodified under the Unicode terms. The three fixtures carry:

```
# © 2025 Unicode®, Inc.
# Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.
# For terms of use and license, see https://www.unicode.org/terms_of_use.html
```

The seven generated tables carry no grant in-file; their Unicode provenance does not extend the Zlib grant to them. The terms text in `LICENCE-UNICODE.txt` is the SHA-256 `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` byte stream of `https://www.unicode.org/license.txt`, fetched 2026-10-03.

The Unicode terms state:

> All Unicode Data Files and Unicode Software are subject to the terms and conditions of the free and open-source Unicode License v3, unless otherwise indicated by specific restriction, permission, or license identified at the point of release or in such software, data file, or other documentation.

## Separate grant for `tools/linebreak_test.c`

This program's separate grant applies to that file only:

```
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  You may
freely use it without any restrictions, including copying the
whole or part of it to use in other programs.
```

## Upstream files without in-file notices

These 35 pinned upstream files carry no in-file notice. Except for the separate-grant file above, the upstream tree-level `LICENCE` covers the upstream files; the Unicode files are listed separately because they have different terms.

```
src/test_skips.h
src/Makefile.am       src/Makefile.gcc        src/Makefile.msvc
src/generate_linebreakdata.py    src/generate_linebreak_aux.py
src/generate_word_break.py       src/generate_grapheme_break.py
src/generate_east_asian_width.py src/generate_indic_conjunct_break.py
src/generate_extended_pictographic.py
src/unicode_data_property.py
src/extract_data.sed  src/expand_single.sed
src/linebreakdata1.tmpl
Makefile.am  configure.ac  autogen.sh  bootstrap  purge
libunibreak.pc.in  Doxyfile  .clang-format  .mailmap  .gitignore
README.upstream.md  NEWS  AUTHORS  doc/architecture.md
tools/test.txt
tools/wordbreak_test.c  tools/graphemebreak_test.c
tools/linebreak_bench.c  tools/wordbreak_bench.c
tools/graphemebreak_bench.c
```

`tools/wordbreak_test.c`, `tools/graphemebreak_test.c`, `tools/linebreak_bench.c`, `tools/wordbreak_bench.c`, `tools/graphemebreak_bench.c` and `tools/test.txt` have no notice of their own; the tree-level grant applies. `LICENCE`, `README.upstream.md` and `AUTHORS` are upstream files. `AUTHORS` carries no licence notice of its own. The complete fork-authored file list and grant are in `FORK-LICENSE.md`.
