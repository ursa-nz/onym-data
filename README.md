<!--
SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# onym-data

The owned WordNet data supply chain for Onym. It holds every byte the engine reads, vendored and
content-addressed by commit, so the three frontends consume one pinned data set through a git
submodule. Project context is in the umbrella `PLAN.md`; this repository is the `data/` slot.

The runtime needs no network. `prepare.sh` decompresses the vendored blob into a plain WordNet data
directory the engine opens over an explicit path. Only maintainer-side regeneration fetches anything,
and that goes to `scratch/`, which is never committed.

## Layout

```
base/
  wndb.tar.zst     the WordNet base graph in WNDB format, compressed
  VERSION          the edition identifier; first line is read by the tests
overlays/
  etym.onym        the etymology overlay, additive and absent-by-default
recipes/
  fetch-sources.sh fetches the heavy raw inputs into scratch/, on demand, never vendored
  build.sh         regenerates base/ and the overlays from the fetched sources
  SOURCES.lock     the URLs, checksums and dates each artefact was built from
tests/
  validate.sh      structural and parse checks that gate every data change
  coverage.sh      writes the committed coverage report and holds a regression floor
  coverage-report.txt
prepare.sh         materialises base/ and overlays/ into one data directory, offline
PROVENANCE.md      every source, edition, checksum and licence
LICENSES/          the licence texts the vendored data and the scripts carry
```

## Preparing a data directory

```sh
./prepare.sh [TARGET_DIR]   # default: build/wordnet
```

It decompresses the base graph into `TARGET_DIR` and copies each overlay beside it. The engine reads
`etym.onym` from the same directory as the WordNet files (engine.md section 6.10), so one directory
holds everything.

## Regenerating the data

```sh
recipes/fetch-sources.sh        # heavy raw inputs into scratch/, on demand
recipes/build.sh                # rebuild base/wndb.tar.zst and overlays/etym.onym
```

`recipes/build.sh` reads the engine's overlay producer from a sibling `../core` checkout. The raw
sources it consumes are recorded in `recipes/SOURCES.lock`.

## Validation and coverage

```sh
tests/validate.sh               # required files present, base parses, blob integrity
tests/coverage.sh               # overlay coverage against the committed floor
```

These gate every data bump. `validate.sh` also runs the engine's conformance kit against the prepared
base when a sibling `../core` build is present, which is the byte-exact parity check. The base is
validated overlay-free, the way the conformance fixtures are generated; the overlay is checked on its
own.

## The pin

A given engine commit maps to an exact data commit, which maps to exact output. The pin is a
bumpable submodule commit gated by the tests here, not an immutable checksum freeze. Each consumer
repository bumps its own pointer when it chooses.
