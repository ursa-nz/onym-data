#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Gate every data change. Materialises the base into a temporary directory and checks the structural
# invariants the engine relies on, with no network. When a sibling ../core build supplies onym-dump,
# it also runs the engine's conformance kit against the prepared base, which is the byte-exact parity
# check; without it, the structural checks still stand. The base is validated overlay-free, the way
# the conformance fixtures are generated.
#
# Usage: tests/validate.sh

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

fail=0
note() { printf '  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "==> prepare base into a scratch directory"
"$here/prepare.sh" --base-only "$tmp/wordnet" >/dev/null

echo "==> required WordNet files present and non-empty"
required="data.noun data.verb data.adj data.adv \
          index.noun index.verb index.adj index.adv \
          noun.exc verb.exc adj.exc adv.exc \
          cntlist.rev sentidx.vrb sents.vrb"
for f in $required; do
  if [ ! -s "$tmp/wordnet/$f" ]; then bad "missing or empty: $f"; fi
done
note "checked $(printf '%s\n' $required | wc -w) base files"

echo "==> data.* structural invariants"
for pos in noun verb adj adv; do
  # Every data line starts with an 8-digit offset, then a 2-digit lex_filenum, then the ss_type, and
  # carries a gloss separated by ' | '. A malformed line here is a base the parser would reject.
  awkout=$(awk '
    /^[0-9]/ {
      total++
      if ($1 !~ /^[0-9]{8}$/) { offset++ }
      if ($0 !~ / \| /)       { gloss++ }
      if ($3 !~ /^[nvasr]$/)  { sstype++ }
    }
    END { printf "%d %d %d %d", total, offset+0, gloss+0, sstype+0 }
  ' "$tmp/wordnet/data.$pos")
  set -- $awkout
  [ "$1" -gt 0 ] || bad "data.$pos has no synset lines"
  [ "$2" -eq 0 ] || bad "data.$pos: $2 lines with a non-8-digit offset"
  [ "$3" -eq 0 ] || bad "data.$pos: $3 lines with no gloss separator"
  [ "$4" -eq 0 ] || bad "data.$pos: $4 lines with an unknown ss_type"
  note "data.$pos: $1 synsets, all well-formed"
done

echo "==> overlays present and well-formed"
# A plain .onym reads directly; a compressed .onym.zst is decompressed to check it, the same form
# prepare.sh lays down for the engine.
for overlay in etym.onym omw.onym.zst; do
  src="$here/overlays/$overlay"
  if [ -s "$src" ]; then
    case "$overlay" in
      *.zst) reader="zstd -dc --" ;;
      *) reader="cat --" ;;
    esac
    if $reader "$src" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
      note "$overlay is valid UTF-8"
    else
      bad "$overlay is not valid UTF-8"
    fi
  else
    bad "overlays/$overlay missing or empty"
  fi
done

echo "==> engine conformance against the prepared base (if a dumper is available)"
dump="${ONYM_DUMP:-$here/../core/target/release/onym-dump}"
runner="$here/../core/conformance/run-conformance"
if [ -x "$dump" ] && [ -x "$runner" ]; then
  # The base was prepared overlay-free above, the way the conformance fixtures are generated.
  if "$runner" "$dump" --data "$tmp/wordnet" >/dev/null 2>&1; then
    note "conformance kit passes against the prepared base"
  else
    bad "conformance kit fails against the prepared base"
  fi
else
  note "skipped: no onym-dump at $dump (build ../core to enable)"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "validate: $fail check(s) failed"
  exit 1
fi
echo "validate: all checks passed"
