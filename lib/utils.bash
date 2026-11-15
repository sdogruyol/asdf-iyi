#!/usr/bin/env bash
# Shared helpers for the iyi asdf/mise plugin.
#
# Sourced by the scripts in bin/; never executed on its own.

set -euo pipefail

# Where releases live. IYI_REPO_URL is only used to enumerate tags, so a fork
# with the same release assets can be listed by overriding it.
IYI_REPO_URL="${IYI_REPO_URL:-https://github.com/iyilang/iyi.git}"
IYI_RELEASES="${IYI_RELEASES:-https://github.com/iyilang/iyi/releases/download}"

fail() {
  printf 'asdf-iyi: %s\n' "$*" >&2
  exit 1
}

# Print $1 without a leading "v", rejecting anything that is not a dotted
# numeric release version. The leading "v" is a tag convention, not part of
# the version the release files use.
normalize_version() {
  local version="${1#v}"
  case "$version" in
    '' | *[!0-9.]*) fail "not an iyi release version: $1" ;;
    .* | *. | *..*) fail "not an iyi release version: $1" ;;
  esac
  printf '%s\n' "$version"
}

# All released versions, oldest first, one per line.
#
# Tags are the source of truth, read over Git so this neither needs a token
# nor hits the GitHub API rate limit. The LLVM toolchain release in the same
# repository (tooling-llvm-*) is filtered out by accepting dotted numbers only.
# Git's version sort is used because `sort -V` is not portable to macOS.
iyi_versions() {
  local versions
  if ! versions="$(
    git ls-remote --tags --refs --sort='v:refname' "$IYI_REPO_URL" 2>/dev/null |
      sed 's|.*refs/tags/||' |
      grep -E '^v?[0-9]+(\.[0-9]+)+$' |
      sed 's/^v//'
  )"; then
    fail "could not list iyi releases from $IYI_REPO_URL (git and network access are required)"
  fi
  [ -n "$versions" ] || fail "no iyi releases found at $IYI_REPO_URL"
  printf '%s\n' "$versions"
}

# True when version $1 sorts before version $2. Dotted numbers only, so awk
# can compare each component; this keeps the check portable without sort -V.
version_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, A, ".")
    nb = split(b, B, ".")
    n = na > nb ? na : nb
    for (i = 1; i <= n; i++) {
      x = (i <= na ? A[i] : 0) + 0
      y = (i <= nb ? B[i] : 0) + 0
      if (x < y) exit 0
      if (x > y) exit 1
    }
    exit 1
  }'
}

# Set IYI_OS, IYI_ARCH, IYI_TARGET and IYI_EXT for the current machine.
# Takes the version so the error names the release that is missing.
iyi_target() {
  local version="$1" os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT) os=windows ;;
    *) fail "iyi $version has no release for $os: releases ship Linux x86_64, macOS arm64 and Windows x86_64" ;;
  esac

  case "$arch" in
    x86_64 | amd64) arch=x86_64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) fail "iyi $version has no release for $os $arch: releases ship Linux x86_64, macOS arm64 and Windows x86_64" ;;
  esac

  case "$os-$arch" in
    linux-x86_64 | darwin-arm64 | windows-x86_64) ;;
    *) fail "iyi $version has no release for $os $arch: releases ship Linux x86_64, macOS arm64 and Windows x86_64" ;;
  esac

  IYI_OS="$os"
  IYI_ARCH="$arch"
  IYI_TARGET="$os-$arch"
  case "$os" in
    windows) IYI_EXT=zip ;;
    *) IYI_EXT=tar.gz ;;
  esac
}

# Release archive name for version $1 on the current target.
iyi_asset() {
  printf 'iyi-%s-%s.%s\n' "$1" "$IYI_TARGET" "$IYI_EXT"
}

# The compiler's file name inside the archive.
iyi_binary() {
  if [ "$IYI_OS" = windows ]; then
    printf 'iyi.exe\n'
  else
    printf 'iyi\n'
  fi
}

# Fetch a release URL. HTTPS with TLS 1.2 or newer, or a local file:// URL
# (which is how a release is installed before it is published).
iyi_fetch() {
  local url="$1"
  shift
  case "$url" in
    https://*) curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fSL "$@" "$url" ;;
    file://*) curl -fSL "$@" "$url" ;;
    *) fail "refusing to fetch $url: only https:// and file:// URLs are supported" ;;
  esac
}

iyi_sha256() {
  local file="$1" sum
  if command -v sha256sum >/dev/null 2>&1; then
    sum="$(sha256sum "$file")" || fail "could not checksum $file"
  elif command -v shasum >/dev/null 2>&1; then
    sum="$(shasum -a 256 "$file")" || fail "could not checksum $file"
  else
    fail "sha256sum or shasum is required to verify $file"
  fi
  printf '%s\n' "${sum%% *}"
}

# Verify archive $1 against the SHA256SUMS file $2.
iyi_verify() {
  local archive="$1" sums="$2" asset expected actual
  asset="$(basename "$archive")"
  expected="$(awk -v name="$asset" '$2 == name || $2 == "*" name { print $1; exit }' "$sums")"
  [ -n "$expected" ] || fail "SHA256SUMS has no entry for $asset"
  actual="$(iyi_sha256 "$archive")"
  [ "$actual" = "$expected" ] ||
    fail "$asset failed checksum verification: expected $expected, got $actual"
}

# Base URL for version $1's release files, without a trailing slash.
iyi_release_base() {
  local base="${IYI_RELEASE_URL:-$IYI_RELEASES/v$1}"
  printf '%s\n' "${base%/}"
}
