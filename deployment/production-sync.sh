#!/bin/bash
# Controlled MMEC production sync. No deletions are performed by this script.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
umask 077
MODE=${1:-plan}
SOURCE=${2:-/home1/mdhiglob/repositories/mmecglobal-website}
LIVE=${3:-/home1/mdhiglob/public_html/mmecglobal}
REPORTS=${4:-/home1/mdhiglob/deployment-reports/mmecglobal}
case "$MODE" in plan|apply) ;; *) echo 'Usage: production-sync.sh plan|apply' >&2; exit 2;; esac
test -s "$SOURCE/index.html" && test -d "$LIVE"
SOURCE=$(cd "$SOURCE" && pwd -P)
LIVE=$(cd "$LIVE" && pwd -P)
test "$SOURCE" != "$LIVE" && test "$SOURCE" != / && test "$LIVE" != /
REPORTS=$(realpath -m -- "$REPORTS")
case "$REPORTS/" in "$LIVE/"*|"$SOURCE/"*) echo 'Report directory overlaps website or repository' >&2; exit 1;; esac
mkdir -p -- "$REPORTS"
REPORTS=$(cd "$REPORTS" && pwd -P)
case "$REPORTS/" in "$LIVE/"*|"$SOURCE/"*) exit 1;; esac
STAMP=$(date -u +%Y%m%dT%H%M%SZ)-$$
REPORT="$REPORTS/production-$MODE-$STAMP.txt"
BACKUP="$REPORTS/overwritten-$STAMP"
RSYNC=$(command -v rsync)
COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
echo "Mode: $MODE; commit: $COMMIT; source: $SOURCE; target: $LIVE" > "$REPORT"
echo 'No live-only files will be deleted. PHP handlers and server configuration are excluded.' >> "$REPORT"
FILTER=(
  --exclude='.git' --exclude='.github/'
  --exclude='/.cpanel.yml' --exclude='/.gitignore'
  --exclude='/README.md' --exclude='/deployment/'
  --exclude='.htaccess' --exclude='.well-known/'
  --exclude='.user.ini' --exclude='php.ini'
  --exclude='.env' --exclude='.env.*' --exclude='.htpasswd'
  --include='/form-handler-v2.php'
  --exclude='*.php' --exclude='logs/' --exclude='*.log'
  --exclude='.vscode/' --exclude='.idea/' --exclude='__MACOSX/'
  --exclude='.DS_Store' --exclude='._*' --exclude='Thumbs.db'
)
if test "$MODE" = plan; then
  "$RSYNC" -rcpn --itemize-changes "${FILTER[@]}" "$SOURCE/" "$LIVE/" >> "$REPORT" 2>&1
  echo "Plan: $REPORT"
else
  mkdir -p -- "$BACKUP"
  "$RSYNC" -rcp --chmod=D755,F644 --backup --backup-dir="$BACKUP" --itemize-changes \
    "${FILTER[@]}" "$SOURCE/" "$LIVE/" >> "$REPORT" 2>&1
  echo "Published commit: $COMMIT"
  echo "Changed-file backups: $BACKUP"
  echo "Report: $REPORT"
fi
