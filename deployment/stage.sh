#!/bin/bash
# Build a separate test site; never change the live MMEC directory.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
umask 077
SOURCE=/home1/mdhiglob/repositories/mmecglobal-website
LIVE=/home1/mdhiglob/public_html/mmecglobal
STAGE=/home1/mdhiglob/public_html/mmecglobal-preview
REPORTS=/home1/mdhiglob/deployment-reports/mmecglobal
RSYNC=$(command -v rsync) || { echo "rsync unavailable" >&2; exit 1; }
test -s "$SOURCE/index.html"
test -d "$LIVE"
test "$(cd "$SOURCE" && pwd -P)" = "$SOURCE"
test "$(cd "$LIVE" && pwd -P)" = "$LIVE"
test ! -L "$STAGE"
test "$STAGE" != "$LIVE"
test "$STAGE" != "$SOURCE"
test "$(cd "$(dirname "$STAGE")" && pwd -P)" = "$(dirname "$STAGE")"
DEPENDENCIES="$SOURCE/deployment/live-dependencies.txt"
test -s "$DEPENDENCIES"
# Validate every fallback before touching the preview.
while IFS= read -r relative || test -n "$relative"; do
    case "$relative" in ""|/*|*..*) echo "Invalid fallback path" >&2; exit 1;; esac
    test -f "$LIVE/$relative"
    test ! -L "$LIVE/$relative"
done < "$DEPENDENCIES"
mkdir -p "$REPORTS"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
REPORT="$REPORTS/stage-$STAMP.txt"
exec > >(tee "$REPORT") 2>&1
echo "MMEC test-site build"
echo "Commit: $(git -C "$SOURCE" rev-parse HEAD)"
echo "Live directory is read-only for this script: $LIVE"
# Export the seven missing dependencies privately for adding back to GitHub.
tar -czf "$REPORTS/live-dependencies-$STAMP.tar.gz" -C "$LIVE" -T "$DEPENDENCIES"
mkdir -p "$STAGE"
test "$(cd "$STAGE" && pwd -P)" = "$STAGE"
"$RSYNC" -rcp --chmod=D755,F644 --delete --itemize-changes \
    --exclude='.git' --exclude='.github/' \
    --exclude='/.cpanel.yml' --exclude='/.gitignore' \
    --exclude='/README.md' --exclude='/deployment/' \
    --exclude='.htaccess' --exclude='.well-known/' \
    --exclude='.env' --exclude='.env.*' --exclude='.user.ini' \
    --exclude='php.ini' --exclude='.htpasswd' \
    --exclude='.vscode/' --exclude='.idea/' --exclude='__MACOSX/' \
    --exclude='.DS_Store' --exclude='._*' --exclude='Thumbs.db' \
    --exclude='*.log' --exclude='logs/' \
    "$SOURCE/" "$STAGE/"
while IFS= read -r relative || test -n "$relative"; do
    mkdir -p "$STAGE/$(dirname "$relative")"
    cp "$LIVE/$relative" "$STAGE/$relative"
    chmod 644 "$STAGE/$relative"
    echo "Restored live dependency to preview: $relative"
done < "$DEPENDENCIES"
# The preview must not become an indexed duplicate of the production website.
cat > "$STAGE/.htaccess" <<'HTACCESS'
Options -Indexes
<IfModule mod_headers.c>
    Header always set X-Robots-Tag "noindex, nofollow, noarchive"
</IfModule>
HTACCESS
chmod 644 "$STAGE/.htaccess"
cat > "$STAGE/robots.txt" <<'ROBOTS'
User-agent: *
Disallow: /
ROBOTS
chmod 644 "$STAGE/robots.txt"
# Add noindex metadata to every HTML document even if mod_headers is unavailable.
while IFS= read -r -d '' html; do
    sed -i '0,/<head[^>]*>/s/<head[^>]*>/&<meta name="robots" content="noindex, nofollow, noarchive">/' "$html"
done < <(find "$STAGE" -type f -name '*.html' -print0)
echo "Preview: https://mdhiglobal.com/mmecglobal-preview/"
echo "Dependency archive: $REPORTS/live-dependencies-$STAMP.tar.gz"
echo "Build report: $REPORT"
echo "---- STAGING COMPLETE: production files unchanged ----"
