#!/bin/bash
# Compare only. This script never copies or removes website files.
set -euo pipefail
umask 077
export PATH=/usr/local/bin:/usr/bin:/bin
SOURCE=/home1/mdhiglob/repositories/mmecglobal-website
TARGET=/home1/mdhiglob/public_html/mmecglobal
REPORT_DIR=/home1/mdhiglob/deployment-reports/mmecglobal
RSYNC=$(command -v rsync) || { echo "rsync is unavailable; no website files changed." >&2; exit 1; }
test -s "$SOURCE/index.html" || { echo "Source index.html missing; stopped." >&2; exit 1; }
test -d "$TARGET" || { echo "Live directory missing; stopped." >&2; exit 1; }
test "$(cd "$SOURCE" && pwd -P)" = "$SOURCE" || exit 1
test "$(cd "$TARGET" && pwd -P)" = "$TARGET" || exit 1
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/compare-$(date -u +%Y%m%dT%H%M%SZ)-$$.txt"
# These exclusions also protect destination files from proposed deletion.
# Do not add --delete-excluded.
{
    echo "MMEC comparison only - no website files changed"
    echo "Source: $SOURCE"
    echo "Target: $TARGET"
    echo "Commit: $(git -C "$SOURCE" rev-parse HEAD)"
    echo "Legend: *deleting = proposed removal; >f+++++++++ = new; >fc... = content changed."
    echo "Protected: .well-known, .htaccess, .user.ini, php.ini, .env files, .htpasswd, logs."
    echo "PHP handlers, PDFs and media are compared, NOT assumed safe to replace or delete."
    echo "---- PROPOSED CHANGES ----"
    "$RSYNC" -rcn --delete --itemize-changes --out-format='%i|%n%L' \
        --exclude='.git' --exclude='.github/' \
        --exclude='/.cpanel.yml' --exclude='/.gitignore' \
        --exclude='/README.md' --exclude='/deployment/' \
        --exclude='.well-known/' --exclude='.htaccess' \
        --exclude='.user.ini' --exclude='php.ini' \
        --exclude='.env' --exclude='.env.*' --exclude='.htpasswd' \
        --exclude='logs/' --exclude='*.log' \
        --exclude='.vscode/' --exclude='.idea/' --exclude='__MACOSX/' \
        --exclude='.DS_Store' --exclude='._*' --exclude='Thumbs.db' \
        "$SOURCE/" "$TARGET/"
    echo "---- COMPARISON COMPLETE ----"
} > "$REPORT" 2>&1
echo "Comparison report: $REPORT"
echo "Download this report with File Manager. The live website is unchanged."
