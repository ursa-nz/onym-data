#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ursa.nz <code@ursa.nz>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Fetch the heavy raw sources the vendored artefacts are built from, into scratch/ (never committed,
# never shipped). Run this before recipes/build.sh. Maintainer-side only; the runtime needs none of
# it.
#
# The base graph comes from Open English WordNet 2025, the Plus edition with proper nouns. The
# producer is the OEWNTK grind_xml2wndb chain, which this script builds from source: the chain is not
# on Maven Central at the version the current master needs, and its newest source is what built the
# reference WNDB. Build it under a JDK no newer than 21, because Kotlin 2.1.0's bundled version parser
# throws on JDK 25. Set OEWN_JAVA_HOME (or JAVA_HOME) to such a JDK; mvn must be on PATH.
#
# Usage: recipes/fetch-sources.sh [scratch-dir]   (default: scratch/ beside this repo)

set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$here/scratch"}
mkdir -p "$scratch"

export JAVA_HOME=${OEWN_JAVA_HOME:-${JAVA_HOME:?set OEWN_JAVA_HOME or JAVA_HOME to a JDK <= 21}}

# OEWN 2025 Plus, the merged LMF XML release asset (OEWN plus Open English Namenet).
plus_url="https://github.com/globalwordnet/english-wordnet/releases/download/2025-edition/english-wordnet-2025-plus.xml.gz"
plus_sha256="31f4af16c54b532fd5484d4cc33aee588a31bb5b70683ae8197842fde5b586bc"

# The grinder's extra inputs, which the merged XML does not carry: verb sentence templates, the
# sense-to-template map, and the sense-to-tag-count map. The maintainer's own build inputs, committed
# in oewntk/fromxml.
declare -A xml2_sha256=(
  [verbTemplates.xml]="45420bd39d4767c9bb287aaf84c5779d19bca97453369ae7f1a1ac8a294dd0b8"
  [senseToVerbTemplates.xml]="952f45a340986b63a0a47e7139376a525ecb08bd8975d951f03b3b66a77b2ec3"
  [senseToTagCounts.xml]="f18929fa727a2b6c1c56bd9d60cb0cdce6a2619b23e7fd7708a436b2ec56a29e"
)

# OEWNTK chain, pinned to the commits the base was ground with.
declare -A oewntk_commit=(
  [model]="996a3daaa1cf307b38071ad5a40922e62d4fb084"
  [fromxml]="d8eb0bee19b194b7d132b5f6eabf29f93c458f88"
  [towndb]="fe70924d791c20c6f4e1c6acf46c70d11f4d4285"
  [grind_xml2wndb]="f2164c2f8def0ae056fb46935ce0f6c451d67b92"
)

# The wiktextract English extract from kaikki.org: English headwords with parsed etymology prose.
wikt_url="https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"

echo "==> OEWN 2025 Plus XML"
curl -sSL -o "$scratch/english-wordnet-2025-plus.xml.gz" "$plus_url"
echo "$plus_sha256  $scratch/english-wordnet-2025-plus.xml.gz" | sha256sum -c -

echo "==> grinder extras (oewntk/fromxml xml2)"
mkdir -p "$scratch/xml2"
for f in "${!xml2_sha256[@]}"; do
  curl -sSL -o "$scratch/xml2/$f" \
    "https://raw.githubusercontent.com/oewntk/fromxml/${oewntk_commit[fromxml]}/xml2/$f"
  echo "${xml2_sha256[$f]}  $scratch/xml2/$f" | sha256sum -c -
done

echo "==> OEWNTK chain (build from pinned source)"
m2="$scratch/.m2repo"
src="$scratch/oewntk"
mkdir -p "$m2" "$src"
mvnflags="-B -Dmaven.repo.local=$m2 -DskipTests \
  -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.httpconnectionManager.ttlSeconds=120"
for r in model fromxml towndb grind_xml2wndb; do
  if [ ! -d "$src/$r/.git" ]; then
    git clone "https://github.com/oewntk/$r.git" "$src/$r"
  fi
  git -C "$src/$r" fetch -q --depth 1 origin "${oewntk_commit[$r]}"
  git -C "$src/$r" checkout -q "${oewntk_commit[$r]}"
done
# Compile and install the three libraries without the package-phase plugins (dokka pulls a ~100 MB
# descriptor jar and signs nothing we need). Then compile the grinder and pin its runtime classpath.
for r in model fromxml towndb; do
  ( cd "$src/$r" \
      && mvn $mvnflags compile \
      && mvn $mvnflags jar:jar \
      && mvn $mvnflags install:install-file -Dfile="target/$r-3.0.1.jar" -DpomFile=pom.xml )
done
( cd "$src/grind_xml2wndb" \
    && mvn $mvnflags compile \
    && mvn $mvnflags dependency:build-classpath -Dmdep.outputFile="$src/grind.cp" )

echo "==> wiktextract (kaikki.org English)"
curl -sSL -o "$scratch/wikt-en.jsonl.gz" "$wikt_url"
wikt_sha256="$(sha256sum "$scratch/wikt-en.jsonl.gz" | cut -d' ' -f1)"
wikt_date="$(curl -sI "$wikt_url" | awk -F': ' 'tolower($1)=="last-modified"{print $2}' | tr -d '\r')"
echo "    last-modified $wikt_date"
echo "    sha256 $wikt_sha256"
echo
echo "Sources fetched to $scratch. Record any changed checksum in recipes/SOURCES.lock."
