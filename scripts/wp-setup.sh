#!/usr/bin/env bash
# wp-setup.sh — idempotent WordPress + WooCommerce install
# Works in both apache and fpm containers (WP-CLI available in both)
# Usage: docker compose exec wordpress-fpm wp-setup.sh
set -uo pipefail   # NOTE: -e intentionally omitted so plugin installs can fail gracefully

WP_URL="${WP_URL:-http://localhost:8080}"
WP_ADMIN="${WP_ADMIN:-admin}"
WP_PASS="${WP_PASS:-admin123}"
WP_EMAIL="${WP_EMAIL:-admin@example.com}"
WP_TITLE="${WP_TITLE:-WP Stress Demo — WCEU 2026}"
WP_DIR="${WP_DIR:-/var/www/html}"

export WP_CLI_ALLOW_ROOT=1

cd "$WP_DIR"

echo "==> Waiting for database..."
until wp db check --quiet 2>/dev/null; do
  sleep 2
done

echo "==> Checking WordPress install status..."
if ! wp core is-installed 2>/dev/null; then
  echo "==> Installing WordPress..."
  wp core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN" \
    --admin_password="$WP_PASS" \
    --admin_email="$WP_EMAIL" \
    --skip-email
fi

echo "==> WordPress version: $(wp core version)"

# ── Permalink structure (needed for WooCommerce and cache keys)
wp rewrite structure '/%postname%/' --hard

# ── Plugins (non-fatal — network may be unavailable in air-gapped envs)
echo "==> Installing plugins (network required for first run)..."
wp plugin install redis-cache --activate 2>&1 || echo "  [WARN] redis-cache install failed — skipping"
wp plugin install woocommerce --activate 2>&1 || echo "  [WARN] woocommerce install failed — skipping"
wp plugin install wordpress-seo 2>&1 || echo "  [WARN] wordpress-seo install failed — skipping"

# ── WooCommerce setup (only if WooCommerce is active)
if wp plugin is-active woocommerce 2>/dev/null; then
  echo "==> Configuring WooCommerce..."
  wp wc tool run install_pages --user=admin 2>&1 || true
  wp option update woocommerce_store_address "1 Demo Street" 2>/dev/null || true
  wp option update woocommerce_default_country "BG" 2>/dev/null || true
  wp option update woocommerce_currency "EUR" 2>/dev/null || true
else
  echo "  [INFO] WooCommerce not active — skipping WC setup"
fi

# ── Redis object cache connection (only if plugin is active)
if wp plugin is-active redis-cache 2>/dev/null; then
  echo "==> Enabling Redis object cache..."
  wp redis enable 2>/dev/null || true
else
  echo "  [INFO] Redis Cache plugin not active — skipping"
fi

# ── Demo content: 10 posts (single call)
echo "==> Seeding minimal demo content..."
wp post generate --count=10 --post_status=publish --quiet 2>/dev/null || true

# ── WooCommerce demo products (only if WC active)
if wp plugin is-active woocommerce 2>/dev/null; then
  wp eval '
    global $wpdb;
    $now = current_time("mysql");
    for ($i = 1; $i <= 5; $i++) {
      $price = rand(5, 100) . ".99";
      $wpdb->insert($wpdb->posts, [
        "post_title" => "Test Product $i", "post_status" => "publish",
        "post_type" => "product", "post_author" => 1,
        "post_date" => $now, "post_date_gmt" => $now,
        "post_modified" => $now, "post_modified_gmt" => $now,
        "post_name" => "test-product-$i", "comment_status" => "open",
      ]);
      $pid = $wpdb->insert_id;
      foreach (["_price" => $price, "_regular_price" => $price,
                "_stock_status" => "instock", "_visibility" => "visible"] as $k => $v) {
        $wpdb->insert($wpdb->postmeta, ["post_id" => $pid, "meta_key" => $k, "meta_value" => $v]);
      }
    }
    echo "Created 5 demo products\n";
  ' 2>/dev/null || true
fi

# ── Update site URL if needed
wp option update siteurl "$WP_URL" --quiet
wp option update home "$WP_URL" --quiet

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  WordPress ready!                                ║"
echo "║  Frontend: $WP_URL"
echo "║  Admin:    $WP_URL/wp-admin"
echo "║  User:     $WP_ADMIN / $WP_PASS"
echo "╚══════════════════════════════════════════════════╝"
