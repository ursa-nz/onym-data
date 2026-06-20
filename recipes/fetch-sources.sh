#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Fetch the heavy raw sources the vendored artefacts are built from, into scratch/ (never committed,
# never shipped). Run this before recipes/build.sh. Maintainer-side only; the runtime needs none of
# it. The WordNet base is pinned by checksum because it is frozen; the wiktextract extract is dated
# and its checksum recorded at fetch time, because kaikki.org republishes it as Wiktionary changes.
#
# Usage: recipes/fetch-sources.sh [scratch-dir]   (default: scratch/ beside this repo)

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$here/scratch"}
mkdir -p "$scratch"

# Princeton WordNet 3.0, Debian wordnet-base, pinned exactly as the engine's data tooling pins it so
# the base joins against identical bytes.
wordnet_deb_url="https://deb.debian.org/debian/pool/main/w/wordnet/wordnet-base_3.0-41_all.deb"
wordnet_deb_sha256="e50d14b2ee444eaf36ef2a3bd38e50c623b47ba22b2301adc4a5f12736da9264"

# The wiktextract English extract from kaikki.org: English headwords with parsed etymology prose.
wikt_url="https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"

echo "==> WordNet (Debian wordnet-base 3.0-41)"
if [ ! -d "$scratch/wordnet" ]; then
  curl -sSL -o "$scratch/wordnet-base.deb" "$wordnet_deb_url"
  echo "$wordnet_deb_sha256  $scratch/wordnet-base.deb" | sha256sum -c -
  ( cd "$scratch" && ar x wordnet-base.deb && tar -xJf data.tar.xz )
  mv "$scratch/usr/share/wordnet" "$scratch/wordnet"
  rm -rf "$scratch/usr" "$scratch/control.tar.xz" "$scratch/data.tar.xz" \
         "$scratch/debian-binary" "$scratch/wordnet-base.deb"
fi
echo "    $scratch/wordnet ($(ls "$scratch/wordnet" | wc -l) files)"

echo "==> wiktextract (kaikki.org English)"
curl -sSL -o "$scratch/wikt-en.jsonl.gz" "$wikt_url"
wikt_sha256="$(sha256sum "$scratch/wikt-en.jsonl.gz" | cut -d' ' -f1)"
wikt_date="$(curl -sI "$wikt_url" | awk -F': ' 'tolower($1)=="last-modified"{print $2}' | tr -d '\r')"
echo "    $scratch/wikt-en.jsonl.gz ($(du -h "$scratch/wikt-en.jsonl.gz" | cut -f1))"
echo "    last-modified $wikt_date"
echo "    sha256 $wikt_sha256"
echo
echo "Sources fetched to $scratch. Record any changed checksum in recipes/SOURCES.lock."
