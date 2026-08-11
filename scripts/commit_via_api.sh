#!/usr/bin/env bash
# Commit the files listed in hash_update_result.txt through GitHub's Git Data
# API instead of `git commit`/`git push`. Commits made this way are shown as
# "Verified" by GitHub automatically (GitHub itself signs them), unlike a
# plain CLI commit pushed with GITHUB_TOKEN, which shows as unverified even
# though the push itself is authenticated.
#
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN), jq.
# Env vars: REPO ("owner/repo"), BRANCH (branch to update).
set -euo pipefail

RESULT_FILE="hash_update_result.txt"
COMMIT_MESSAGE="chore: sync pinned release hashes with upstream"

if [ ! -s "$RESULT_FILE" ]; then
  echo "No changed files to commit."
  exit 0
fi

mapfile -t FILES < "$RESULT_FILE"

base_commit_sha=$(gh api "repos/$REPO/git/ref/heads/$BRANCH" --jq '.object.sha')
base_tree_sha=$(gh api "repos/$REPO/git/commits/$base_commit_sha" --jq '.tree.sha')

tree_entries="[]"
for file in "${FILES[@]}"; do
  echo "Creating blob for $file ..."
  blob_sha=$(gh api "repos/$REPO/git/blobs" -f content="$(base64 -w0 "$file")" -f encoding=base64 --jq '.sha')
  tree_entries=$(jq -c --arg path "$file" --arg sha "$blob_sha" \
    '. + [{path: $path, mode: "100644", type: "blob", sha: $sha}]' <<< "$tree_entries")
done

new_tree_sha=$(jq -n --arg base_tree "$base_tree_sha" --argjson tree "$tree_entries" \
  '{base_tree: $base_tree, tree: $tree}' | gh api "repos/$REPO/git/trees" --input - --jq '.sha')

new_commit_sha=$(jq -n --arg message "$COMMIT_MESSAGE" --arg tree "$new_tree_sha" --arg parent "$base_commit_sha" \
  '{message: $message, tree: $tree, parents: [$parent]}' | gh api "repos/$REPO/git/commits" --input - --jq '.sha')

echo "Fast-forwarding $BRANCH to $new_commit_sha ..."
gh api "repos/$REPO/git/refs/heads/$BRANCH" -X PATCH -f sha="$new_commit_sha" -F force=false
