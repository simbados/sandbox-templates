#!/usr/bin/env bash
# Save the allow rules scoped to individual sandboxes before running
# `sbx policy reset`, which deletes the whole local policy store. Global rules
# (including the Balanced preset's baseline) are left out on purpose.
#
# It isn't documented whether `sbx policy ls <name>` lists only that sandbox's
# rules or also the global ones that apply to it, so each sandbox's list is
# compared against the global list and only the extra lines are kept.
#
# Run on the host (sbx isn't available inside a sandbox).
# Usage: scripts/backup_sandbox_policies.sh <sandbox>... (names from `sbx ls`)
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <sandbox>..." >&2
  exit 1
fi

OUT_DIR="${OUT_DIR:-$HOME/sbx-policy-backup}"
mkdir -p "$OUT_DIR"

sbx policy ls --decision allow > "$OUT_DIR/global.txt"

for sb in "$@"; do
  sbx policy ls "$sb" --decision allow > "$OUT_DIR/sb-$sb.txt"
  echo "== $sb"
  grep -vxFf "$OUT_DIR/global.txt" "$OUT_DIR/sb-$sb.txt" || true
done | tee "$OUT_DIR/sandbox-rules.txt"

echo "Saved to $OUT_DIR/sandbox-rules.txt; review it before running sbx policy reset." >&2
