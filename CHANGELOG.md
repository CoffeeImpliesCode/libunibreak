# Changelog

Fork changes relative to upstream libunibreak 8.0.

- Port to Zig 0.17.0.
- The consumer step installs non-native targets instead of running them because Zig 0.17 does not expose emulator settings during configuration.
- The nested consumer build uses its package-local install prefix because Zig 0.17 exposes the parent prefix only as a make-time path.
- The nested consumer build forwards target, CPU, linkage, runtime, cache environment and program arguments.
- `Decode.utf32` preserves a stored `0xFFFFFFFF` code point and identifies end-of-input by index.
- Typed grapheme methods skip the native call on empty input to avoid upstream's out-of-bounds write; the raw C API remains unchanged.
- Added typed `Line`, `Word` and `Grapheme` APIs with caller-owned buffers, input validation and errors, alongside the translated C API.
- Typed `Word` and `Grapheme` methods omit upstream's unused `lang` parameter; typed line breaking retains its language option.
- Added explicit-provider runtime loading with no provider fallback.
- The build provides static (default) and shared artifacts plus relocatable pkg-config metadata.
- The build compiles upstream's nine declared C translation units explicitly as C99.
- Added Nix static/shared outputs and a tools-only devenv shell.
- Install carries the upstream Zlib text, Unicode terms, conformance fixtures and `tools/test.txt` with the library.
