#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Rebuild the vendored artefacts from the fetched raw sources. Run recipes/fetch-sources.sh first.
# Maintainer-side only. The base blob is built reproducibly (sorted entries, fixed timestamps and
# ownership) so an unchanged source produces an unchanged blob and the git history does not churn.
#
# Usage: recipes/build.sh [scratch-dir] [core-checkout]
#   scratch-dir    default: scratch/ beside this repo (holds the fetched sources and the built chain)
#   core-checkout  default: ../core (holds the etymology overlay producer)

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$here/scratch"}
core=${2:-"$here/../core"}

plus_gz="$scratch/english-wordnet-2025-plus.xml.gz"
xml2="$scratch/xml2"
grind_cp="$scratch/oewntk/grind.cp"
grind_classes="$scratch/oewntk/grind_xml2wndb/target/classes"
wndb="$scratch/wordnet"

[ -f "$plus_gz" ] || { echo "missing $plus_gz; run recipes/fetch-sources.sh" >&2; exit 1; }
[ -f "$grind_cp" ] || { echo "missing $grind_cp; run recipes/fetch-sources.sh" >&2; exit 1; }

export JAVA_HOME=${OEWN_JAVA_HOME:-${JAVA_HOME:?set OEWN_JAVA_HOME or JAVA_HOME to a JDK <= 21}}

echo "==> grind OEWN 2025 Plus to WNDB (from $plus_gz)"
mkdir -p "$wndb"
if [ ! -f "$scratch/oewn-plus.xml" ]; then
  gunzip -c "$plus_gz" > "$scratch/oewn-plus.xml"
fi
"$JAVA_HOME/bin/java" -ea -cp "$grind_classes:$(cat "$grind_cp")" \
  org.oewntk.grind.xml2wndb.Grind "$scratch/oewn-plus.xml" "$xml2" "$wndb"

echo "==> base/wndb.tar.zst (from $wndb)"
tar --sort=name --mtime='2026-01-01 00:00:00' --owner=0 --group=0 --numeric-owner \
    -cf - -C "$wndb" . \
  | zstd -q -19 -o "$here/base/wndb.tar.zst.new"
mv -f "$here/base/wndb.tar.zst.new" "$here/base/wndb.tar.zst"
echo "    $(du -h "$here/base/wndb.tar.zst" | cut -f1)  sha256 $(sha256sum "$here/base/wndb.tar.zst" | cut -d' ' -f1)"

echo "==> overlays/etym.onym (via $core/tools/build-overlay.sh, against the OEWN lemma set)"
if [ -x "$core/tools/build-overlay.sh" ] && [ -f "$scratch/wikt-en.jsonl.gz" ]; then
  # The producer reads the lemma set from the base's index files and joins the wiktextract prose to
  # it, so it is pointed at the freshly ground WNDB. The data dir it wants holds wordnet/ and
  # wikt-en.jsonl.gz; scratch/ is that dir once wordnet/ exists.
  "$core/tools/build-overlay.sh" "$scratch" "$here/overlays/etym.onym"
  echo "    $(du -h "$here/overlays/etym.onym" | cut -f1)"
else
  echo "    skipped: need $core/tools/build-overlay.sh and $scratch/wikt-en.jsonl.gz" >&2
fi

echo
echo "Rebuilt. Update recipes/SOURCES.lock and run tests/validate.sh and tests/coverage.sh."
