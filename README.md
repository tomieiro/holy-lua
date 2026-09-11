# Lua for HolyC / TempleOS

This repository is an independent porting workspace for bringing a usable Lua
nucleus to HolyC and TempleOS. It is not the official Lua project, is not
affiliated with or endorsed by Lua.org or PUC-Rio, and is not a replacement
for the official Lua distribution.

## Provenance and scope

This repository was created from a fork of the official Lua source repository.
The Lua 5.4.9 reference snapshot is kept in `src/lua/` so the port can be
compared with upstream. Port-specific work is under
`src/platform/templeos/`, `src/templeos/`, and the HolyC tests.

The goal is to adapt Lua's runtime concepts to HolyC and TempleOS, replacing
POSIX/libc facilities such as `malloc`, `realloc`, `free`, `setjmp`,
`longjmp`, `FILE`, `stdio`, dynamic loading, signals, locale, and time APIs
with explicit TempleOS-facing boundaries. This is a port in progress, not a
claim that the complete Lua VM and standard library already run on TempleOS.

## Current status

The executable HolyC nucleus in `src/platform/templeos/lua_mini.hc` currently
covers a deliberately bounded language subset:

- numbers, strings, booleans, `nil`, arithmetic, modulo, comparisons,
  concatenation, truthiness, and `and`/`or` short-circuiting;
- local/global assignments and block scoping;
- `if`/`elseif`/`else`, `while`, numeric `for`, `repeat`/`until`, `break`,
  `goto`, and labels;
- user-defined functions, multiple arguments, and recursive calls;
- fixed-capacity array-style tables with indexing, nesting, length, growth,
  and identity equality;
- a small registry for calling HolyC native functions through an `hcc`-safe
  output-parameter ABI.

This nucleus is useful for TempleOS experiments, but it is not yet the full
Lua interpreter. It has fixed limits, no closures/upvalues, no string-keyed
tables in the mini language, no multiple return values, and no complete
garbage collector. The parallel runtime building blocks in `lua_memory.hc`,
`lua_state.hc`, `lua_table.hc`, `lua_string.hc`, `lua_gc.hc`, and
`lua_call.hc` still need to be connected to the full Lua implementation.

The detailed inventory is in [`docs/port-status.md`](docs/port-status.md).
The semantic map for agents is [`AICP.aicp`](AICP.aicp).

## Repository layout

```text
src/lua/                         upstream Lua 5.4.9 reference snapshot
src/platform/templeos/           HolyC platform and nucleus code
src/templeos/                    TempleOS HolyC entrypoints
tests/lua/testes/                upstream Lua host test suite
tests/holyc_*.hc                 HolyC smoke and nucleus tests
docs/                            port status and design notes
build/                           local generated artifacts, ignored by Git
AICP.aicp                        semantic repository map
Makefile                         host and TempleOS preparation commands
LICENSE.md                      MIT license for this port repository
```

New repository source files use lowercase extensions, including `.hc`. The
`tos.HH` include is the external filename installed by `hcc` and remains
capitalized because it does not belong to this repository.

## Requirements and commands

The host reference build requires a C compiler, Make, and the system math,
dynamic-loading, and readline libraries. HolyC validation uses `hcc`; the
development environment was validated with `hcc v0.0.15-beta`, which provides
`/usr/local/include/tos.HH`. Final compatibility must also be checked inside
the target TempleOS environment.

```sh
make host             # build the upstream/reference host interpreter
make test             # run the upstream Lua test suite
make templeos-prepare # collect .hc sources for a TempleOS-side build
make clean            # remove local generated artifacts
```

Direct HolyC checks with `hcc` are:

```sh
mkdir -p build/hcc
hcc -c -o build/hcc/lua-platform.o src/platform/templeos/templeos_api.hc
hcc -c -o build/hcc/lua-entry.o src/templeos/lua.hc
hcc -c -o build/hcc/lua-mini.o src/platform/templeos/lua_mini.hc
hcc -jit tests/holyc_mini.hc
```

`make templeos-prepare` only stages `.hc` files. It is not a TempleOS
cross-compiler; compilation and execution in a real TempleOS image remain
separate steps.

## Porting strategy

The upstream C implementation remains the behavioral reference. The planned
sequence is to connect the HolyC allocator to Lua's `frealloc`, replace
non-local error handling, port console/filesystem support, then progressively
connect the VM, parser, GC, and libraries. Only after those foundations are
stable should the HolyC extension API be finalized.

Platform-specific substitutions belong behind
`src/platform/templeos/templeos_api.hc`, rather than being scattered through
the reference sources. Intentional deviations should have focused HolyC tests
and entries in `docs/port-status.md`.

## License and relationship to Lua

The HolyC porting code and repository contributions are released under the
[MIT License](LICENSE.md). The upstream Lua source in `src/lua/` retains its
original Lua license and copyright notices; those notices must remain intact
in redistributions of that snapshot.

This repository's HolyC porting code is an independent derivative work built
around that upstream snapshot. Nothing here is an official Lua release, an
official TempleOS release, or an endorsement by Lua.org, PUC-Rio, or the
TempleOS project. Official Lua questions belong on the
[Lua mailing list](https://www.lua.org/lua-l.html); official releases are at
[Lua.org](https://www.lua.org/download.html).

## Contributing

Keep upstream/reference changes separate from HolyC adaptations. Prefer small
commits organized by one runtime capability, add reproducible checks, and
update `AICP.aicp` whenever architecture, contracts, tests, or port tasks
change.
