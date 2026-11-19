#!/bin/bash
set -euo pipefail

# Succeeds when the merge group commit has the PR head's tree and the head's gate passed.
# A failed lookup leaves the trees or the gate unmatched, so the queue runs every check.
decide() {
  [ "$GITHUB_EVENT_NAME" = merge_group ] || return 1
  local pr pr_head group_tree pr_tree gate
  pr=$(sed -n 's#.*/pr-\([0-9][0-9]*\)-.*#\1#p' <<<"$GROUP_REF")
  [ -n "$pr" ] || return 1
  pr_head=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$pr" --jq .head.sha)
  group_tree=$(gh api "repos/$GITHUB_REPOSITORY/git/commits/$GROUP_SHA" --jq .tree.sha)
  pr_tree=$(gh api "repos/$GITHUB_REPOSITORY/git/commits/$pr_head" --jq .tree.sha)
  gate=$(gh api "repos/$GITHUB_REPOSITORY/commits/$pr_head/status" \
    --jq '[.statuses[] | select(.context == "All Required Checks Passed")][0].state // "none"')
  echo "PR #$pr head ${pr_head:0:8} tree ${pr_tree:0:8}; group ${GROUP_SHA:0:8} tree ${group_tree:0:8}; gate $gate"
  [ "$gate" = success ]
}

if decide; then redundant=true; else redundant=false; fi
echo "redundant=$redundant" >>"$GITHUB_OUTPUT"
echo "Skip every check of this merge group: $redundant"
