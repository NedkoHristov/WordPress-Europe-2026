#!/usr/bin/env bash
# static/build.sh — export WordPress as a static site using WP-CLI + wget
# Outputs to static/export/ which is served by the static-site container
set -euo pipefail

EXPORT_DIR="$(dirname "$0")/export"
WP_URL="${WP_URL:-http://localhost:8080}"

echo "==> Cleaning previous export..."
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo "==> Crawling WordPress at $WP_URL ..."
wget \
  --mirror \
  --convert-links \
  --adjust-extension \
  --page-requisites \
  --no-parent \
  --directory-prefix="$EXPORT_DIR" \
  --no-host-directories \
  --reject="wp-login.php,wp-admin,xmlrpc.php,feed,comments" \
  --quiet \
  --show-progress \
  "$WP_URL" 2>&1 | cat || true

# Fix internal links to point to static paths
echo "==> Post-processing links..."
find "$EXPORT_DIR" -name "*.html" -exec \
  sed -i "s|$WP_URL||g" {} \; 2>/dev/null || true

echo ""
echo "==> Static export complete!"
echo "    Files: $(find "$EXPORT_DIR" -type f | wc -l | tr -d ' ')"
echo "    Size:  $(du -sh "$EXPORT_DIR" | cut -f1)"
echo ""
echo "    Static site runs at http://localhost:8090"
echo "    Dynamic islands (cart, search) still hit http://localhost:8080/wp-json/"
