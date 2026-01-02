#!/bin/bash

# Sync local infuse-artwork folder to R2 bucket
# This will make R2 match the local folder exactly (including deletions)

echo "Syncing infuse-artwork/ to R2..."

rclone sync infuse-artwork/ r2:infuse-artwork \
  --filter '- .DS_Store' \
  --filter '- .wrangler/**' \
  --filter '- node_modules/**' \
  -v

echo ""
echo "Sync complete!"
