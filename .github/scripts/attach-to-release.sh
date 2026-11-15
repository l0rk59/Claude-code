#!/usr/bin/env bash
# Adds a file to the release of a version tag, creating the release when
# the other builds haven't yet (the APK and the computer app are built at
# the same time).
#
# Usage: attach-to-release.sh <tag> <version from pubspec.yaml> <file>
set -euo pipefail

tag="$1"
version="$2"
file="$3"

if [ "${tag#v}" != "$version" ]; then
  echo "::error::The tag ($tag) and pubspec.yaml's version ($version) differ: the update check compares them."
  exit 1
fi

for attempt in 1 2 3 4 5; do
  if gh release view "$tag" > /dev/null 2>&1; then
    break
  fi
  # Another build may create it at the same moment: then just retry.
  if gh release create "$tag" --title "PrivateLM $version" --generate-notes; then
    break
  fi
  sleep $((attempt * 5))
done

gh release upload "$tag" "$file" --clobber
