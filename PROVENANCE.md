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
files), compressed with zstd. Edition `oewn-2025`, see `base/VERSION`.

- Source: Open English WordNet 2025, the lossless Plus edition with proper nouns, built from the OEWN
  release asset `english-wordnet-2025-plus.xml.gz` (OEWN plus Open English Namenet) through the
  OEWNTK `grind_xml2wndb` chain. The grinder also reads the verb-template and tag-count extras from
  `oewntk/fromxml`.
- Upstream URLs, checksums and toolchain commits: `recipes/SOURCES.lock`.
- Producer: `recipes/build.sh`, which builds the OEWNTK chain from source and grinds the WNDB.
- Licence: CC-BY-4.0, with the underlying Princeton WordNet terms preserved. OEWN distributes the
  Plus edition as an official flavour of the 2025 release under CC-BY-4.0, and its own WordNet licence
  text confirms the Princeton-derived parts ship under the same terms. Attribution is due to both the
  Open English WordNet team and Princeton University. The proper nouns come from Open English Namenet,
  drawn from Wikidata, which is CC0, so they impose no further condition. Text in
  `LICENSES/CC-BY-4.0.txt`, with the Princeton grant retained in `LICENSES/LicenseRef-WordNet.txt`.
- Contents: `data.{noun,verb,adj,adv}`, `index.{noun,verb,adj,adv}`, the four `*.exc`, `cntlist.rev`,
  `cntlist`, `sentidx.vrb`, `sents.vrb`, `index.sense`, `lexnames`, `verb.Framestext`. The engine
  reads the first set; the extras are carried so the bytes are a complete WNDB.
- Encoding: UTF-8. OEWN's WNDB is UTF-8 throughout, where Princeton 3.0 was ISO-8859-1. Non-ASCII is
  confined to glosses and accented lemmas. The engine reads the base as UTF-8 (engine.md section 3).

## overlays/etym.onym

The etymology overlay (engine.md section 6.10): one preprocessed file of etymology prose keyed by
WordNet query-form lemma, additive and absent-by-default.

- Source: English Wiktionary, parsed by wiktextract and distributed by kaikki.org.
- Upstream URL, checksum and date: `recipes/SOURCES.lock`.
- Producer: the engine's `tools/etym-build` via `tools/build-overlay.sh` in the sibling `../core`
  checkout.
- Licence: CC-BY-SA-3.0, Wiktionary contributors. Text in `LICENSES/CC-BY-SA-3.0.txt`. The overlay
  carries its own provenance header in its leading lines.
- Coverage on the OEWN 2025 base: 66,223 of 152,459 WordNet lemmas, about 43%. Absolute coverage
  rose against the 3.0 base (65,031 matched) as OEWN's larger lemma set gave more to join to. The
  current figure and the regression floor are in `tests/coverage-report.txt`.
