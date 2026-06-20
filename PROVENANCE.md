<!--
SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Provenance

Every vendored artefact, the source it was built from, and its licence. The vendored files are
compiled artefacts; the heavy raw sources they derive from are fetched on demand by
`recipes/fetch-sources.sh` and never committed.

## base/wndb.tar.zst

The WordNet base graph in WNDB format (the Princeton `index.*` / `data.*` layout plus the side
files), compressed with zstd. Edition `pwn-3.0`, see `base/VERSION`.

- Source: Princeton WordNet 3.0, as packaged by Debian `wordnet-base_3.0-41_all.deb`.
- Upstream URL and checksum: `recipes/SOURCES.lock`.
- Licence: WordNet 3.0 licence, a permissive BSD-style grant from Princeton University. Text in
  `LICENSES/LicenseRef-WordNet.txt`.
- Contents: `data.{noun,verb,adj,adv}`, `index.{noun,verb,adj,adv}`, the four `*.exc`, `cntlist.rev`,
  `sentidx.vrb`, `sents.vrb`. This is the set the engine reads; it carries no `lexnames` or
  `index.sense`, which the engine does not use.

At the cutover (PLAN.md step 3) this artefact is rebuilt from Open English WordNet 2025, the lossless
WNDB release with proper nouns (the Plus edition), licence CC-BY-4.0. The VERSION identifier changes
to `oewn-2025` and this section is rewritten.

## overlays/etym.onym

The etymology overlay (engine.md section 6.10): one preprocessed file of etymology prose keyed by
WordNet query-form lemma, additive and absent-by-default.

- Source: English Wiktionary, parsed by wiktextract and distributed by kaikki.org.
- Upstream URL, checksum and date: `recipes/SOURCES.lock`.
- Producer: the engine's `tools/etym-build` via `tools/build-overlay.sh` in the sibling `../core`
  checkout.
- Licence: CC-BY-SA-3.0, Wiktionary contributors. Text in `LICENSES/CC-BY-SA-3.0.txt`. The overlay
  carries its own provenance header in its leading lines.
- Coverage on the 3.0 base: about 44% of WordNet lemmas. The current figure and floor are in
  `tests/coverage-report.txt`.
