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

## overlays/omw.onym.zst

The translations overlay (engine.md section 6.11): one preprocessed file listing, per synset, the
words other languages use for that concept, keyed by the WNDB part of speech and offset, additive and
absent-by-default. Vendored zstd-compressed (about 1 MiB against 3.5 MiB raw); `prepare.sh`
decompresses it to `omw.onym` in the data dir, which is what the engine reads.

- Source: the Open Multilingual Wordnet components, each a WN-LMF wordnet aligned to the
  Collaborative Interlingual Index. The working set is the licence-clean trio vetted in the producer
  go/no-go: MultiWordNet (Italian), Wordnet Bahasa (Indonesian), and OpenWN-PT (Portuguese). More
  components from PLAN section 8 drop in by adding their tarball to `recipes/fetch-sources.sh`.
- Join: each OEWN synset carries an ILI in the release LMF, and so does each OMW component synset, so
  the join is ILI to ILI inside the producer. The WNDB offset the engine reads is bridged from the
  base's own `index.sense`, so the key is tied to the exact bytes the engine opens. CILI is the
  shared index both sides are aligned to; it is fetched for provenance and as the licence anchor
  (CC-BY-4.0), not read for the join.
- Upstream URLs, checksums and the per-component licences: `recipes/SOURCES.lock`.
- Producer: the engine's `tools/omw-build` via `tools/build-omw.sh` in the sibling `../core` checkout,
  run after the base grind so it reads the freshly built `index.sense`.
- Licence: per component, each on its own terms, credited individually. MultiWordNet CC-BY-3.0 (FBK,
  text in `LICENSES/CC-BY-3.0.txt`); Wordnet Bahasa MIT (text in `LICENSES/MIT.txt`); OpenWN-PT
  CC-BY-SA-3.0 (text in `LICENSES/CC-BY-SA-3.0.txt`). The share-alike sits on the data, not on the
  engine code. The overlay carries its own provenance and language legend in its leading lines.
- Coverage on the OEWN 2025 base: 66,546 of 117,349 synsets with an ILI carry at least one
  translation, across Indonesian (37,967 synsets), Italian (34,687) and Portuguese (43,787). The
  current figures and the per-language regression floors are in `tests/omw-coverage-report.txt`.
