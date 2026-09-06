#!/bin/bash
#
# Enforces CLAUDE.md's hard rule: no resolution literal may appear in the UI layer.
#
# Scans the app target only. ScreenResizeCore legitimately holds these numbers —
# that is the point of the catalog. A hit here means a number was typed into a
# view that should have come from ResolutionCatalog instead.
#
# Comments are stripped before scanning. String literals are NOT: a hardcoded
# "1920x1080" in a view is precisely the violation being hunted.
#
# Usage: ./scripts/check-ui-literals.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

UI_DIR="ScreenResize"

# Every dimension appearing in ResolutionCatalog.
CATALOG_VALUES="1280|720|1920|1080|2560|1440|3840|2160|7680|4320|1200|1600|3000|2000|640|480|1024|768"

violations=0

while IFS= read -r file; do
  # Strip // comments and /* */ blocks, keeping line numbers intact.
  stripped=$(sed 's://.*::' "$file" | sed 's:/\*.*\*/::')

  # A WxH pair, e.g. 1920x1080 or 1920 × 1080.
  if hits=$(printf '%s\n' "$stripped" | grep -nE '[0-9]{3,4}[[:space:]]*[x×][[:space:]]*[0-9]{3,4}'); then
    while IFS= read -r hit; do
      echo "$file:${hit}" >&2
      violations=$((violations + 1))
    done <<< "$hits"
  fi

  # A standalone catalog value.
  if hits=$(printf '%s\n' "$stripped" | grep -nE "(^|[^0-9.])($CATALOG_VALUES)([^0-9.]|$)"); then
    while IFS= read -r hit; do
      echo "$file:${hit}" >&2
      violations=$((violations + 1))
    done <<< "$hits"
  fi
done < <(find "$UI_DIR" -name '*.swift' -type f)

if [ "$violations" -gt 0 ]; then
  echo "" >&2
  echo "error: $violations resolution literal(s) in the UI layer." >&2
  echo "Resolutions belong in ScreenResizeCore/ResolutionCatalog.swift." >&2
  echo "See CLAUDE.md, 'Resolution presets live in a single data model'." >&2
  exit 1
fi

echo "==> No resolution literals in $UI_DIR"
