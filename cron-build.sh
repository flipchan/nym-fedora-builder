#!/bin/bash
#
# Cron job script: check for new NymVPN releases, build RPMs, deploy to site.
#
# Add to crontab (e.g. check daily at 04:00):
#   0 4 * * * /path/to/cron-build.sh >> /var/log/nym-rpm-build.log 2>&1
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$SCRIPT_DIR"
REPO_DIR="$SCRIPT_DIR/nym-vpn-client"
REPO_URL="https://github.com/nymtech/nym-vpn-client.git"
REPO_BRANCH="develop"
FEDORA_VER=$(rpm -E '%{fedora}' 2>/dev/null || echo "44")
STATE_FILE="$SCRIPT_DIR/.last-built-version"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- clone or update repo ---
if [[ -d "$REPO_DIR/.git" ]]; then
    log "Pulling latest from $REPO_BRANCH..."
    git -C "$REPO_DIR" fetch --tags origin "$REPO_BRANCH"
    git -C "$REPO_DIR" checkout "$REPO_BRANCH"
    git -C "$REPO_DIR" pull --ff-only
else
    log "Cloning $REPO_URL..."
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# --- find latest stable version ---
LATEST=$(git -C "$REPO_DIR" tag -l 'nym-vpn-v*' \
    | grep -vE '(beta|nightly|rc|alpha)' \
    | sed 's/nym-vpn-v//' \
    | sort -V \
    | tail -n1)

if [[ -z "$LATEST" ]]; then
    log "ERROR: Could not determine latest stable version"
    exit 1
fi

log "Latest stable version: $LATEST"

# --- check if already built ---
LAST_BUILT=""
if [[ -f "$STATE_FILE" ]]; then
    LAST_BUILT=$(cat "$STATE_FILE")
fi

if [[ "$LATEST" == "$LAST_BUILT" ]]; then
    log "Version $LATEST already built. Nothing to do."
    exit 0
fi

log "New version detected: $LATEST (was $LAST_BUILT)"

# --- build RPMs ---
BUILD_DIR="$REPO_DIR/nym-vpn-core/crates/nym-vpnd/.pkg/rpm"
cd "$BUILD_DIR"

log "Building RPMs for $LATEST (x86_64 + aarch64)..."
./build-rpms.sh "$LATEST" all

# --- copy RPMs to site ---
RPM_OUT="$BUILD_DIR/rpm-out"
mkdir -p "$SITE_DIR/fedora/$FEDORA_VER"/{x86_64,aarch64}

cp "$RPM_OUT"/nym-vpnd-"$LATEST"-*.x86_64.rpm "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
cp "$RPM_OUT"/nym-vpnc-"$LATEST"-*.x86_64.rpm "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
cp "$RPM_OUT"/nym-vpnd-"$LATEST"-*.aarch64.rpm "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"
cp "$RPM_OUT"/nym-vpnc-"$LATEST"-*.aarch64.rpm "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"

# --- copy GPG key ---
cp "$BUILD_DIR/gpg-key/nym-repo-gpg.asc" "$SITE_DIR/RPM-GPG-KEY-nym"

# --- regenerate repo metadata ---
log "Regenerating repo metadata..."
createrepo_c --update "$SITE_DIR/fedora/$FEDORA_VER/x86_64/" 2>/dev/null || \
    createrepo_c "$SITE_DIR/fedora/$FEDORA_VER/x86_64/"
createrepo_c --update "$SITE_DIR/fedora/$FEDORA_VER/aarch64/" 2>/dev/null || \
    createrepo_c "$SITE_DIR/fedora/$FEDORA_VER/aarch64/"

# --- save state ---
echo "$LATEST" > "$STATE_FILE"

# --- clean old RPMs (keep only latest) ---
for arch in x86_64 aarch64; do
    dir="$SITE_DIR/fedora/$FEDORA_VER/$arch"
    find "$dir" -name 'nym-vpnd-*.rpm' ! -name "*$LATEST*" -delete 2>/dev/null || true
    find "$dir" -name 'nym-vpnc-*.rpm' ! -name "*$LATEST*" -delete 2>/dev/null || true
done

log "Done! Deployed nym-vpnd $LATEST to $SITE_DIR"
