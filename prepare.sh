#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Materialise the vendored base graph and overlays into a plain WordNet data
# directory the engine can open. Offline: it only decompresses files already in
# this repository, fetches nothing, and writes nowhere but the target. This is
# the runtime-side step a build runs; it is what lets a network-isolated builder
# (Flathub, an AppImage recipe) produce a complete data dir with no URL to reach.
#
# Usage: prepare.sh [--base-only] [TARGET_DIR]   (default: build/wordnet beside this script)
#
# The engine reads etym.onym from the same directory as the WordNet files
# (engine.md section 6.10), so by default both land in TARGET_DIR. --base-only
# lays down the WordNet base alone, which is what the overlay-free conformance
# fixtures are checked against.

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

overlays=1
if [ "${1:-}" = "--base-only" ]; then
  overlays=0
  shift
fi
target=${1:-"$here/build/wordnet"}

base_blob="$here/base/wndb.tar.zst"

[ -f "$base_blob" ] || { echo "prepare: missing base blob $base_blob" >&2; exit 1; }

mkdir -p "$target"
# Decompress the base graph in place. zstd and tar are the only tools needed.
zstd -dc -- "$base_blob" | tar -xf - -C "$target"

# Overlays are additive and absent-by-default; lay down each one that exists, unless --base-only. A
# new overlay drops into overlays/ and is materialised here with no further change. A plain .onym is
# copied; a compressed .onym.zst is decompressed to its bare name, so a large overlay ships small but
# the engine still reads a plain file.
if [ "$overlays" -eq 1 ]; then
  for overlay in "$here"/overlays/*.onym; do
    [ -f "$overlay" ] && cp -f -- "$overlay" "$target/$(basename "$overlay")"
  done
  for overlay in "$here"/overlays/*.onym.zst; do
    [ -f "$overlay" ] || continue
    name=$(basename "$overlay" .zst)
    zstd -dc -- "$overlay" > "$target/$name"
  done
fi

echo "$target"
