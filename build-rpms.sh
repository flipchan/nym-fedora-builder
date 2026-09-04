#!/bin/bash
#
# Build nym-vpnd and nym-vpnc RPM packages from GitHub release tarballs.
#
# Usage:
#   ./build-rpms.sh <version> [arch]
#
# Examples:
#   ./build-rpms.sh 2026.12.3              # build for host arch only
#   ./build-rpms.sh 2026.12.3 x86_64       # build for x86_64 only
#   ./build-rpms.sh 2026.12.3 aarch64      # build for aarch64 only
#   ./build-rpms.sh 2026.12.3 all          # build for x86_64 + aarch64
#
# Prerequisites:
#   dnf install -y rpm-build
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:?Usage: $0 <version> [arch|all]}"
ARCHArg="${2:-$(uname -m)}"
SERVICE_FILE="${SCRIPT_DIR}/../aur/nym-vpnd.service"
CONF_FILE="${SCRIPT_DIR}/../sysusers.d/nym-vpn.conf"

# --- sanity checks ---
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "ERROR: service file not found at $SERVICE_FILE" >&2
    exit 1
fi
if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERROR: sysusers conf not found at $CONF_FILE" >&2
    exit 1
fi

# determine which architectures to build
if [[ "$ARCHArg" == "all" ]]; then
    ARCHS=(x86_64 aarch64)
else
    ARCHS=("$ARCHArg")
fi

OUT_DIR="${SCRIPT_DIR}/rpm-out"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

for ARCH in "${ARCHS[@]}"; do
    TARBALL="nym-vpn-core-v${VERSION}_linux_${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-v${VERSION}/${TARBALL}"
    WORK_DIR="$(pwd)/rpm-build-${ARCH}"

    echo ""
    echo "============================================"
    echo "==> Building RPMs for nym-vpnd ${VERSION} (${ARCH})"
    echo "============================================"

    # --- set up rpmbuild tree ---
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    # --- download tarball ---
    echo "==> Downloading ${TARBALL}..."
    curl -fL "$DOWNLOAD_URL" -o "$WORK_DIR/SOURCES/$TARBALL"

    # --- copy supporting files ---
    cp "$SERVICE_FILE" "$WORK_DIR/SOURCES/nym-vpnd.service"
    cp "$CONF_FILE"    "$WORK_DIR/SOURCES/nym-vpn.conf"

    # --- render spec files with version ---
    for spec in nym-vpnd.spec nym-vpnc.spec; do
        sed "s/%{_version}/${VERSION}/g" "$SCRIPT_DIR/$spec" > "$WORK_DIR/SPECS/$spec"
    done

    # --- build RPMs ---
    echo "==> Running rpmbuild for ${ARCH}..."
    rpmbuild -bb \
        --target "$ARCH" \
        --define "_topdir $WORK_DIR" \
        "$WORK_DIR/SPECS/nym-vpnd.spec"

    rpmbuild -bb \
        --target "$ARCH" \
        --define "_topdir $WORK_DIR" \
        "$WORK_DIR/SPECS/nym-vpnc.spec"

    # --- copy output ---
    cp "$WORK_DIR"/RPMS/*/*.rpm "$OUT_DIR/"

    # --- cleanup build dir ---
    rm -rf "$WORK_DIR"
done

echo ""
echo "============================================"
echo "==> All RPMs built successfully:"
ls -1 "$OUT_DIR"/*.rpm
echo ""
echo "==> Output directory: $OUT_DIR"
echo "============================================"
