#!/usr/bin/env bash
# wp-perf-test.sh — before/after performance snapshot
# Writes JSON results to /results/<timestamp>_<label>.json
# Usage inside container: wp-perf-test.sh [before|after|level-0|level-1|level-2]
set -euo pipefail

export WP_CLI_ALLOW_ROOT=1
WP_DIR="${WP_DIR:-/var/www/html}"
LABEL="${1:-snapshot}"
RESULTS_DIR="/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$RESULTS_DIR/${TIMESTAMP}_${LABEL}.json"

mkdir -p "$RESULTS_DIR"
cd "$WP_DIR"

echo "==> Recording performance snapshot: $LABEL"

# Collect metrics
DB_SIZE=$(wp db size --format=csv 2>/dev/null | tail -n1 | awk -F',' '{print $2}' | tr -d '"' || echo "N/A")
POST_COUNT=$(wp post list --post_type=post --format=count 2>/dev/null || echo "0")
REVISION_COUNT=$(wp post list --post_type=revision --format=count 2>/dev/null || echo "0")
COMMENT_COUNT=$(wp comment list --format=count 2>/dev/null || echo "0")
AUTOLOAD_SIZE=$(wp option list --autoload=on --format=csv 2>/dev/null | wc -l || echo "0")
TRANSIENT_COUNT=$(wp transient list --format=count 2>/dev/null || echo "0")

# PHP memory & opcache
OPCACHE=$(php -r "
  \$s = opcache_get_status(false);
  echo json_encode([
    'enabled' => \$s !== false,
    'cached_scripts' => \$s['opcache_statistics']['num_cached_scripts'] ?? 0,
    'hit_rate' => round((\$s['opcache_statistics']['opcache_hit_rate'] ?? 0), 2),
  ]);
" 2>/dev/null || echo '{"enabled":false}')

cat > "$OUT" <<EOF
{
  "label": "$LABEL",
  "timestamp": "$TIMESTAMP",
  "db": {
    "size_bytes": "$DB_SIZE",
    "posts": $POST_COUNT,
    "revisions": $REVISION_COUNT,
    "comments": $COMMENT_COUNT,
    "autoload_rows": $AUTOLOAD_SIZE,
    "transients": $TRANSIENT_COUNT
  },
  "php": {
    "opcache": $OPCACHE
  }
}
EOF

echo "==> Snapshot saved: $OUT"
cat "$OUT"
