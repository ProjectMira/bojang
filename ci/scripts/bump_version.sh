#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Decides the next marketing version (the "X.Y.Z" part of pubspec.yaml's
# `version:`) and writes it back, so every release advances the version the
# store and the in-app settings page show — not just the build number.
#
# Adapted from OpenPecha/WeBuddhist-app's ci/scripts/bump_version.sh.
#
# The level comes from the commits landed since the last release tag:
#
#   major (X+1.0.0) : a "<type>!:" subject or a "BREAKING CHANGE" footer,
#                     or a merged branch named  breaking/*  or  major/*
#   minor (X.Y+1.0) : a "feat:"/"feat(scope):" subject,
#                     or a merged branch named  feat/*  or  feature/*
#   patch (X.Y.Z+1) : everything else, and the fallback when no convention
#                     is used at all — so the version always moves
#
# The "+build" part is left alone: CI passes the real, monotonic build number
# via --build-number (github.run_number), so pubspec's value is a placeholder.
#
# Environment overrides (used by workflow_dispatch inputs):
#   VERSION_BUMP_OVERRIDE = major|minor|patch  force the level
#                         = build-only         leave the version untouched
#   REQUESTED_VERSION     = X.Y.Z              use exactly this version
#
# Outputs (when $GITHUB_OUTPUT is set):
#   marketing=<X.Y.Z>  level=<major|minor|patch|build-only|requested>
# ---------------------------------------------------------------------------
set -euo pipefail

PUBSPEC="${PUBSPEC_PATH:-pubspec.yaml}"

current_line="$(grep -E '^version:' "$PUBSPEC" | head -n1 || true)"
if [ -z "$current_line" ]; then
  echo "::error::$PUBSPEC has no 'version:' line"
  exit 1
fi
current="${current_line#version:}"
current="${current// /}"
name="${current%%+*}"
build=""
if [ "$current" != "$name" ]; then build="${current#*+}"; fi

if ! [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::$PUBSPEC version must be MAJOR.MINOR.PATCH[+BUILD]; got '$name'"
  exit 1
fi

# Highest already-released version, from the v<X.Y.Z>-build.<n> tags.
tag_ver="$(git tag -l 'v*' 2>/dev/null | sed -E 's/^v//; s/-.*$//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1 || true)"

highest() { printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1; }

# A previous run may have committed a bump and then failed before shipping it.
# In that case pubspec is ahead of every tag: release that version rather than
# bumping again, so repeated CI failures cannot run the version away.
pending="no"
if [ -n "$tag_ver" ] && [ "$name" != "$tag_ver" ] && [ "$(highest "$name" "$tag_ver")" = "$name" ]; then
  pending="yes"
fi

level="patch"
new_name="$name"

if [ -n "${REQUESTED_VERSION:-}" ]; then
  new_name="$REQUESTED_VERSION"
  level="requested"
  if ! [[ "$new_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::Requested version must be MAJOR.MINOR.PATCH; got '$new_name'"
    exit 1
  fi
elif [ "${VERSION_BUMP_OVERRIDE:-}" = "build-only" ]; then
  level="build-only"
elif [ "$pending" = "yes" ] && [ -z "${VERSION_BUMP_OVERRIDE:-}" ]; then
  level="pending"
  echo "Reusing the committed but unreleased version $name."
else
  base="$name"
  if [ -n "$tag_ver" ]; then base="$(highest "$name" "$tag_ver")"; fi
  IFS='.' read -r major minor patch <<<"$base"
  : "${major:=0}" "${minor:=0}" "${patch:=0}"

  case "${VERSION_BUMP_OVERRIDE:-}" in
    major | minor | patch)
      level="$VERSION_BUMP_OVERRIDE"
      ;;
    *)
      last_tag="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
      range="HEAD"
      if [ -n "$last_tag" ]; then range="${last_tag}..HEAD"; fi

      subjects="$(git log --format='%s' "$range" 2>/dev/null || true)"
      bodies="$(git log --format='%b' "$range" 2>/dev/null || true)"
      # "Merge pull request #1 from org/feat/x" -> "feat/x"
      branches="$(git log --merges --format='%s' "$range" 2>/dev/null \
        | sed -nE 's/.*from [^/]+\/(.+)$/\1/p' || true)"

      if printf '%s\n' "$subjects" | grep -qiE '^[[:space:]]*(feat|feature)(\([^)]+\))?!?:' \
        || printf '%s\n' "$branches" | grep -qiE '^(feat|feature)/'; then
        level="minor"
      fi
      if printf '%s\n' "$subjects" | grep -qE '^[[:space:]]*[a-z]+(\([^)]+\))?!:' \
        || printf '%s\n' "$bodies" | grep -qE '^[[:space:]]*BREAKING[ -]CHANGE:' \
        || printf '%s\n' "$branches" | grep -qiE '^(breaking|major)/'; then
        level="major"
      fi
      ;;
  esac

  case "$level" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
  esac
  new_name="${major}.${minor}.${patch}"
fi

new_version="$new_name"
if [ -n "$build" ]; then new_version="${new_name}+${build}"; fi

NEW_VERSION="$new_version" perl -i -pe \
  'if (!$done && /^version:/) { $_ = "version: $ENV{NEW_VERSION}\n"; $done = 1 }' "$PUBSPEC"

echo "Last release tag : $(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo '<none>')"
echo "Pubspec version  : $name   (highest released tag: ${tag_ver:-<none>})"
echo "Bump level       : $level"
echo "New version      : $new_name"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "marketing=$new_name"
    echo "level=$level"
  } >>"$GITHUB_OUTPUT"
fi
