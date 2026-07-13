#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/Safe-Net5/Safe-tunnel/main"
MANAGER_URL="$REPO/safe-tunnel.sh"
PY_URL="$REPO/Safe.py"

BIN="/usr/local/bin/safe-tunnel"
PY_DST="/opt/Safe/Safe.py"

MODE="${1:-minimal}"   # minimal | full

err() { echo "[!] $*" >&2; exit 1; }
info() { echo "[*] $*"; }
ok() { echo "[+] $*"; }

# root check
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  err "Please run as root: sudo bash install.sh"
fi

export DEBIAN_FRONTEND=noninteractive

# === بخش جدید: تعمیر خودکار apt ===
info "Checking and fixing apt repositories..."

# پشتیبان‌گیری از sources.list قدیمی (اختیاری)
if [[ -f /etc/apt/sources.list ]]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
fi

# تنظیم مخازن اصلی اوبونتو (مناسب برای Ubuntu 20.04)
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
EOF

info "Cleaning apt cache..."
apt-get clean >/dev/null 2>&1 || true

info "Updating package lists (this may take a moment)..."
apt-get update -y >/dev/null 2>&1 || apt-get update -y || err "Failed to update package lists"

# Minimal deps: run manager + core safely
BASE_DEPS=(curl ca-certificates python3 iproute2 screen)

# Full deps: features you added (cron/iptables/nft/haproxy/socat/ss)
FULL_DEPS=(cron iptables nftables haproxy socat)

info "Installing dependencies ($MODE)..."
if [[ "$MODE" == "full" ]]; then
  apt-get install -y "${BASE_DEPS[@]}" "${FULL_DEPS[@]}" >/dev/null 2>&1 || \
  apt-get install -y "${BASE_DEPS[@]}" "${FULL_DEPS[@]}" >/dev/null 2>&1 || \
  apt-get install -y "${BASE_DEPS[@]}" "${FULL_DEPS[@]}"
else
  apt-get install -y "${BASE_DEPS[@]}" >/dev/null 2>&1 || \
  apt-get install -y "${BASE_DEPS[@]}" >/dev/null 2>&1 || \
  apt-get install -y "${BASE_DEPS[@]}"
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

info "Downloading manager..."
curl -fsSL "$MANAGER_URL" -o "$tmp_dir/safe-tunnel" || err "Failed to download manager"

info "Downloading tunnel core..."
curl -fsSL "$PY_URL" -o "$tmp_dir/Safe.py" || err "Failed to download tunnel core (Safe.py)"

# sanity check: non-empty files
[[ -s "$tmp_dir/safe-tunnel" ]] || err "Downloaded manager is empty"
[[ -s "$tmp_dir/Safe.py" ]] || err "Downloaded core is empty"

install -m 0755 "$tmp_dir/safe-tunnel" "$BIN"
mkdir -p "$(dirname "$PY_DST")"
install -m 0755 "$tmp_dir/Safe.py" "$PY_DST"

echo ""
ok "Installation completed!"
echo ""
echo "Manager installed at: $BIN"
echo "Tunnel core installed at: $PY_DST"
echo ""
echo "Run it with:"
echo "sudo safe-tunnel"
echo ""
echo "Tip:"
echo " - Minimal install: sudo bash install.sh"
echo " - Full install (all features deps): sudo bash install.sh full"
