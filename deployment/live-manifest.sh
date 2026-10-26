#!/bin/bash
# Read website files; write reports only outside the website directory.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
umask 077

LIVE=${1:-/home1/mdhiglob/public_html/mmecglobal}
REPORTS=${2:-/home1/mdhiglob/deployment-reports/mmecglobal}
die() { echo "Scan failed: $*; no complete CSV published." >&2; exit 1; }
for tool in find sort stat sha256sum cmp mktemp; do
    command -v "$tool" >/dev/null || die "$tool is unavailable"
done
test -d "$LIVE" || die "website directory does not exist"
LIVE=$(cd "$LIVE" && pwd -P)
test "$LIVE" != / || die "refusing to scan the filesystem root"
# Resolve before mkdir, so even a rejected report path cannot write in LIVE.
REPORTS=$(realpath -m -- "$REPORTS")
case "$REPORTS/" in "$LIVE/"*) die "reports must be outside the website";; esac
mkdir -p -- "$REPORTS"
REPORTS=$(cd "$REPORTS" && pwd -P)
case "$REPORTS/" in "$LIVE/"*) die "reports resolve inside the website";; esac
WORK=$(mktemp -d "$REPORTS/.manifest-XXXXXXXX")
trap 'rm -rf -- "$WORK"' EXIT
cd "$LIVE"
# Never silently omit links, follow them, or hash files outside the website.
find . -type l -print0 > "$WORK/links"
test ! -s "$WORK/links" || die "symbolic links found; these require separate review"
find . -type f -print0 | sort -z > "$WORK/before"
printf '"Path","Bytes","SHA256"\r\n' > "$WORK/manifest.csv"
COUNT=0
TOTAL=0
while IFS= read -r -d '' file; do
    test ! -L "$file" || die "file became a symbolic link"
    BEFORE=$(stat -c '%s|%y|%z|%i' -- "$file")
    CHECKSUM=$(sha256sum < "$file")
    HASH=${CHECKSUM%% *}
    AFTER=$(stat -c '%s|%y|%z|%i' -- "$file")
    test "$BEFORE" = "$AFTER" || die "a file changed during hashing; rerun when uploads finish"
    test ! -L "$file" || die "file became a symbolic link"
    BYTES=${BEFORE%%|*}
    RELATIVE=${file#./}
    ESCAPED=${RELATIVE//\"/\"\"}
    printf '"%s","%s","%s"\r\n' "$ESCAPED" "$BYTES" "$HASH" >> "$WORK/manifest.csv"
    COUNT=$((COUNT + 1))
    TOTAL=$((TOTAL + BYTES))
    if (( COUNT % 500 == 0 )); then echo "Scanned $COUNT files..."; fi
done < "$WORK/before"
find . -type l -print0 > "$WORK/links-after"
test ! -s "$WORK/links-after" || die "symbolic links appeared during scanning"
find . -type f -print0 | sort -z > "$WORK/after"
cmp -s "$WORK/before" "$WORK/after" || die "file list changed during scanning; rerun"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)-$$
OUTPUT="$REPORTS/MMEC-live-manifest-$STAMP.csv"
mv -- "$WORK/manifest.csv" "$OUTPUT"
echo "Complete: $COUNT files, $TOTAL bytes."
echo "Download with File Manager: $OUTPUT"
echo "Website files were not copied, replaced or deleted."
