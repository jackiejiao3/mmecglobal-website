#!/bin/bash
# Review and quarantine old MMEC assets, never permanently delete them.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
umask 077
MODE=${1:-plan}
LIVE=${2:-/home1/mdhiglob/public_html/mmecglobal}
SOURCE=${3:-/home1/mdhiglob/repositories/mmecglobal-website}
PRIVATE=${4:-/home1/mdhiglob/deployment-reports/mmecglobal}
case "$MODE" in plan|quarantine) ;; *) echo 'Usage: quarantine-old-assets.sh plan|quarantine' >&2; exit 2;; esac
LIVE=$(cd "$LIVE" && pwd -P)
SOURCE=$(cd "$SOURCE" && pwd -P)
PRIVATE=$(cd "$PRIVATE" && pwd -P)
test "$LIVE" != / && test "$SOURCE" != "$LIVE" && test "$PRIVATE" != "$LIVE"
case "$PRIVATE/" in "$LIVE/"*|"$SOURCE/"*) echo 'Unsafe private path' >&2; exit 1;; esac
LIST="$PRIVATE/MMEC-private-cleanup-allowlist.tsv"
test -s "$LIST" || { echo "Private allowlist missing: $LIST" >&2; exit 1; }
# Preserve assets referenced by any page currently present under the live site,
# including pages that are not tracked in the repository.
mapfile -d '' -t PAGE_FILES < <(find "$LIVE" -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.php' \) -print0)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)-$$
REPORT="$PRIVATE/cleanup-$MODE-$STAMP.txt"
QUARANTINE="$PRIVATE/quarantine-$STAMP"
LOCK="$PRIVATE/.cleanup-lock"
mkdir "$LOCK" || { echo 'Another cleanup process is running' >&2; exit 1; }
trap 'rmdir "$LOCK"' EXIT
COUNT=0; BYTES=0; SKIP=0
printf 'Mode: %s\nQuarantine: %s\n' "$MODE" "$QUARANTINE" > "$REPORT"
while IFS=$'\t' read -r REL SIZE SHA || test -n "$REL"; do
  case "$REL" in
    css/*|js/*|images/*|plugins/*) ;;
    *) echo "Invalid candidate path: $REL" >&2; exit 1;;
  esac
  case "/$REL/" in */../*|*/./*|*'//'*) echo "Unsafe path: $REL" >&2; exit 1;; esac
  case "$SIZE:$SHA" in *[!0-9a-f:]*|:*) echo "Invalid metadata: $REL" >&2; exit 1;; esac
  test "${#SHA}" = 64 || { echo "Invalid digest: $REL" >&2; exit 1; }
  FILE="$LIVE/$REL"
  if test -e "$SOURCE/$REL" || test -L "$SOURCE/$REL" || test ! -f "$FILE" || test -L "$FILE"; then
    printf 'SKIP source exists or live file missing/link: %s\n' "$REL" >> "$REPORT"
    SKIP=$((SKIP + 1)); continue
  fi
  if ((${#PAGE_FILES[@]})) && grep -Fq -- "$REL" "${PAGE_FILES[@]}"; then
    printf 'SKIP referenced by live page: %s\n' "$REL" >> "$REPORT"
    SKIP=$((SKIP + 1)); continue
  fi
  PARENT=$(dirname "$FILE")
  if test "$(cd "$PARENT" && pwd -P)" != "$PARENT"; then
    printf 'SKIP linked parent: %s\n' "$REL" >> "$REPORT"
    SKIP=$((SKIP + 1)); continue
  fi
  ACTUAL_SIZE=$(stat -c '%s' -- "$FILE")
  ACTUAL_SHA=$(sha256sum < "$FILE"); ACTUAL_SHA=${ACTUAL_SHA%% *}
  if test "$ACTUAL_SIZE" != "$SIZE" || test "$ACTUAL_SHA" != "$SHA"; then
    printf 'SKIP changed since inventory: %s\n' "$REL" >> "$REPORT"
    SKIP=$((SKIP + 1)); continue
  fi
  if test "$MODE" = quarantine; then
    mkdir -p -- "$QUARANTINE/$(dirname "$REL")"
    test ! -e "$QUARANTINE/$REL"
    mv -- "$FILE" "$QUARANTINE/$REL"
    printf 'MOVED %s\n' "$REL" >> "$REPORT"
  else
    printf 'CANDIDATE %s\n' "$REL" >> "$REPORT"
  fi
  COUNT=$((COUNT + 1)); BYTES=$((BYTES + SIZE))
done < "$LIST"
printf 'Candidates: %s; bytes: %s; skipped: %s\n' "$COUNT" "$BYTES" "$SKIP" >> "$REPORT"
echo "Report: $REPORT"
echo "Candidates: $COUNT; bytes: $BYTES; skipped: $SKIP"
test "$MODE" != quarantine || echo "Restore source if needed: $QUARANTINE"
