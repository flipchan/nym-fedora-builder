#!/bin/bash
#
# Build NymVPN RPM packages for Fedora and deploy to the site directory.
#
# This script:
#   1. Clones the nym-vpn-client repo (or pulls latest)
#   2. Detects the latest stable release tag
#   3. Builds RPMs for x86_64 and aarch64
#   4. Copies RPMs + GPG key into the site directory
#   5. Regenerates repo metadata with createrepo_c
#
# Usage:
#   ./deploy-repo.sh                    # build latest stable
#   ./deploy-repo.sh 2026.12.3          # build specific version
#

set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR=$(mktemp -d)
FEDORA_VER=$(rpm -E '%{fedora}' 2>/dev/null || echo "44")
REPO_URL="https://github.com/nymtech/nym-vpn-client.git"
REPO_BRANCH="develop"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "==> Working directory: $WORK_DIR"

# --- clone the repo ---
echo "==> Cloning nym-vpn-client..."
git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$WORK_DIR/nym-vpn-client"

# --- determine version ---
if [[ -n "${1:-}" ]]; then
    VERSION="$1"
else
    # find latest stable tag (exclude beta/nightly/rc)
    VERSION=$(git -C "$WORK_DIR/nym-vpn-client" tag -l 'nym-vpn-v*' \
        | grep -vE '(beta|nightly|rc|alpha)' \
        | sed 's/nym-vpn-v//' \
        | sort -V \
        | tail -n1)
    if [[ -z "$VERSION" ]]; then
        echo "ERROR: Could not determine latest stable version" >&2
        exit 1
    fi
fi

echo "==> Building version: $VERSION"

# --- build RPMs ---
BUILD_DIR="$WORK_DIR/nym-vpn-client/nym-vpn-core/crates/nym-vpnd/.pkg/rpm"
cd "$BUILD_DIR"
./build-rpms.sh "$VERSION" all

# --- copy RPMs to site ---
RPM_OUT="$BUILD_DIR/rpm-out"
mkdir -p "$SITE_DIR/fedora/$FEDORA_VER"/{x86_64,aarch64}

cp "$RPM_OUT"/nym-vpnd-"$VERSION"-*.x86_64.rpm "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
cp "$RPM_OUT"/nym-vpnc-"$VERSION"-*.x86_64.rpm "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
cp "$RPM_OUT"/nym-vpnd-"$VERSION"-*.aarch64.rpm "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"
cp "$RPM_OUT"/nym-vpnc-"$VERSION"-*.aarch64.rpm "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"

# --- copy GPG key ---
cp "$BUILD_DIR/gpg-key/nym-repo-gpg.asc" "$SITE_DIR/RPM-GPG-KEY-nym"

# --- regenerate repo metadata ---
echo "==> Regenerating repo metadata..."
createrepo_c "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
createrepo_c "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"

# --- summary ---
echo ""
echo "============================================"
echo "==> Deployment ready!"
echo ""
echo "Version: $VERSION"
echo "Fedora:  $FEDORA_VER"
echo ""
echo "Files:"
ls -1 "$SITE_DIR"/RPM-GPG-KEY-nym
ls -1 "$SITE_DIR"/fedora/"$FEDORA_VER"/x86_64/*.rpm
ls -1 "$SITE_DIR"/fedora/"$FEDORA_VER"/aarch64/*.rpm
echo ""
echo "Next: upload $SITE_DIR/ to your webserver"
echo "============================================"
