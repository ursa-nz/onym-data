#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Rebuild the vendored artefacts from the fetched raw sources. Run recipes/fetch-sources.sh first.
# Maintainer-side only. The base blob is built reproducibly (sorted entries, fixed timestamps and
# ownership) so an unchanged source produces an unchanged blob and the git history does not churn.
#
# Usage: recipes/build.sh [scratch-dir] [core-checkout]
#   scratch-dir    default: scratch/ beside this repo (holds wordnet/ and wikt-en.jsonl.gz)
#   core-checkout  default: ../core (holds the etymology overlay producer)

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$here/scratch"}
core=${2:-"$here/../core"}

[ -d "$scratch/wordnet" ] || { echo "missing $scratch/wordnet; run recipes/fetch-sources.sh" >&2; exit 1; }

echo "==> base/wndb.tar.zst (from $scratch/wordnet)"
tar --sort=name --mtime='2026-01-01 00:00:00' --owner=0 --group=0 --numeric-owner \
    -cf - -C "$scratch/wordnet" . \
  | zstd -q -19 -o "$here/base/wndb.tar.zst.new"
mv -f "$here/base/wndb.tar.zst.new" "$here/base/wndb.tar.zst"
echo "    $(du -h "$here/base/wndb.tar.zst" | cut -f1)  sha256 $(sha256sum "$here/base/wndb.tar.zst" | cut -d' ' -f1)"

echo "==> overlays/etym.onym (via $core/tools/build-overlay.sh)"
if [ -x "$core/tools/build-overlay.sh" ] && [ -f "$scratch/wikt-en.jsonl.gz" ]; then
  # The producer expects a data dir holding wordnet/ and wikt-en.jsonl.gz, which scratch/ is.
  "$core/tools/build-overlay.sh" "$scratch" "$here/overlays/etym.onym"
  echo "    $(du -h "$here/overlays/etym.onym" | cut -f1)"
else
  echo "    skipped: need $core/tools/build-overlay.sh and $scratch/wikt-en.jsonl.gz" >&2
fi

echo
echo "Rebuilt. Update recipes/SOURCES.lock and run tests/validate.sh and tests/coverage.sh."
