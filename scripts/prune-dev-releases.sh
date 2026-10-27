#!/bin/bash
# Deletes all but the newest <keep> development pre-releases (tag dev-*) together with their tags. Only pre-releases whose
# tag starts with "dev-" are ever selected: v* releases are never touched.
# Usage: scripts/prune-dev-releases.sh <keep>      (needs gh, authenticated for the repository)
set -euo pipefail

KEEP=${1:?usage: prune-dev-releases.sh <number of dev pre-releases to keep>}
[[ "$KEEP" =~ ^[0-9]+$ ]] || { echo "keep must be a number, got '$KEEP'" >&2; exit 1; }

old=$(gh release list --limit 200 --json tagName,isPrerelease,createdAt \
  --jq "[.[] | select(.isPrerelease and (.tagName | startswith(\"dev-\")))] | sort_by(.createdAt) | reverse | .[$KEEP:] | .[].tagName")

if [ -z "$old" ]; then
  echo "nothing to prune (keeping the newest $KEEP dev pre-releases)"
  exit 0
fi

for tag in $old; do
  echo "deleting $tag"
  gh release delete "$tag" --cleanup-tag --yes
done
