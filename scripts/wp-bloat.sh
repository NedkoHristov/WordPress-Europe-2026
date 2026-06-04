#!/usr/bin/env bash
# wp-bloat.sh — seed realistic WordPress database bloat
# Produces: 2.5k posts (~5k post revisions), 500 WooCommerce products (+1.5k revisions),
#           800 expired transients, 750 spam comments, 4500 orphaned meta rows
# Uses single wp eval PHP loops — no per-row WP-CLI subprocess overhead.
# Runtime: ~2-4 min depending on hardware.
set -uo pipefail

export WP_CLI_ALLOW_ROOT=1
WP_DIR="${WP_DIR:-/var/www/html}"
cd "$WP_DIR"

echo "==> Starting database bloat seeding..."
echo "    Watch Grafana MySQL dashboard → Threads Running + QPS will spike"

# ── 2,500 posts (in batches of 500)
echo "==> Creating 2,500 posts..."
for batch in $(seq 1 5); do
  wp post generate --count=500 --post_status=publish --quiet
  echo "    Batch $batch/5 done ($(( batch * 500 )) posts)"
done

# ── ~5,000 post revisions via single PHP eval (fast — no per-call WP bootstrap)
echo "==> Creating ~5,000 post revisions (single PHP loop)..."
wp eval '
  $ids = get_posts(["numberposts" => 2500, "fields" => "ids", "post_type" => "post"]);
  $count = 0;
  foreach ($ids as $pid) {
    wp_save_post_revision($pid);
    wp_save_post_revision($pid);
    $count += 2;
  }
  echo "    Created $count post revisions\n";
' 2>/dev/null || true
echo "    Post revisions done"

# ── 500 WooCommerce products + 3 revisions each via single PHP eval (fast)
echo "==> Creating 500 WooCommerce products + 1,500 revisions (single PHP loop)..."
echo "    Watch Grafana MySQL InnoDB I/O panel."
wp eval '
  global $wpdb;
  $now  = current_time("mysql");
  $cats = ["Electronics","Clothing","Books","Home","Sports","Toys","Beauty","Garden","Food","Tools"];
  for ($i = 1; $i <= 500; $i++) {
    $cat   = $cats[$i % 10];
    $price = rand(5, 200);
    $wpdb->insert($wpdb->posts, [
      "post_title"        => "Demo Product $i — $cat",
      "post_content"      => "High-quality $cat item #$i for performance testing.",
      "post_status"       => "publish",
      "post_type"         => "product",
      "post_author"       => 1,
      "post_date"         => $now,
      "post_date_gmt"     => $now,
      "post_modified"     => $now,
      "post_modified_gmt" => $now,
      "post_name"         => "demo-product-$i",
      "comment_status"    => "open",
    ]);
    $pid = $wpdb->insert_id;
    foreach (["_price" => $price, "_regular_price" => $price,
              "_stock_status" => "instock", "_visibility" => "visible",
              "_manage_stock" => "no", "total_sales" => 0] as $k => $v) {
      $wpdb->insert($wpdb->postmeta, ["post_id" => $pid, "meta_key" => $k, "meta_value" => $v]);
    }
    // 3 revisions per product
    for ($r = 1; $r <= 3; $r++) {
      $wpdb->insert($wpdb->posts, [
        "post_title"        => "Demo Product $i — $cat",
        "post_content"      => "Edit $r — updated content for product $i.",
        "post_status"       => "inherit",
        "post_type"         => "revision",
        "post_parent"       => $pid,
        "post_name"         => "$pid-revision-v$r",
        "post_author"       => 1,
        "post_date"         => $now,
        "post_date_gmt"     => $now,
        "post_modified"     => $now,
        "post_modified_gmt" => $now,
      ]);
    }
    if ($i % 100 === 0) echo "  $i/500 products\n";
  }
  echo "Products + revisions done\n";
' 2>/dev/null || true
echo "    Products done"

# ── 750 spam comments
echo "==> Creating 750 spam comments..."
wp comment generate --count=750 --post_id=1 --quiet 2>/dev/null || true
# Mark all generated comments as spam via single SQL (no per-row WP-CLI loop)
wp eval '
  global $wpdb;
  $updated = $wpdb->query("UPDATE {$wpdb->comments} SET comment_approved = \"spam\" WHERE comment_approved = \"1\"");
  echo "Marked $updated comments as spam\n";
' 2>/dev/null || true

# ── 800 expired transients (simulate plugin abuse)
echo "==> Inserting 800 expired transients..."
wp eval '
  global $wpdb;
  $now = time();
  for ($i = 0; $i < 800; $i++) {
    $key     = "bloat_demo_$i";
    $wpdb->query( $wpdb->prepare(
      "INSERT IGNORE INTO {$wpdb->options} (option_name, option_value, autoload) VALUES (%s, %s, %s)",
      "_transient_$key", "cached_data_$i", "yes"
    ));
    $wpdb->query( $wpdb->prepare(
      "INSERT IGNORE INTO {$wpdb->options} (option_name, option_value, autoload) VALUES (%s, %s, %s)",
      "_transient_timeout_$key", (string)($now - 3600), "no"
    ));
  }
  echo "Inserted 800 expired transients\n";
'

# ── 4,500 orphaned postmeta rows
echo "==> Inserting 4,500 orphaned postmeta rows..."
wp eval '
  global $wpdb;
  for ($i = 0; $i < 4500; $i++) {
    $wpdb->query( $wpdb->prepare(
      "INSERT INTO {$wpdb->postmeta} (post_id, meta_key, meta_value) VALUES (%d, %s, %s)",
      999999, "orphaned_meta_$i", "value_$i"
    ));
  }
  echo "Inserted 4500 orphaned postmeta rows\n";
'

# ── Final DB size report
echo "==> Database size after bloat:"
wp db size --tables | cat

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Bloat seeding complete!                             ║"
echo "║  DB now has:                                         ║"
echo "║   2,500 posts + ~5,000 revisions                     ║"
echo "║   500 products + 1,500 revisions                     ║"
echo "║   800 expired transients, 750 spam comments          ║"
echo "║   4,500 orphaned meta rows                           ║"
echo "║                                                      ║"
echo "║  Now run: make load-crash                            ║"
echo "║  Watch:   Grafana 03-mysql → Threads Running spike   ║"
echo "╚══════════════════════════════════════════════════════╝"

echo "║   800 expired transients, 750 spam comments      ║"
echo "║   4500 orphaned meta rows                        ║"
echo "║                                                  ║"
echo "║  Now run: make load-crash                        ║"
echo "║  Then:    Screenshot Grafana 03-mysql dashboard  ║"
echo "╚══════════════════════════════════════════════════╝"
