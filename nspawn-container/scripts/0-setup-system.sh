#!/bin/bash
# This script installs systemd-container if it's not installed.
# Also links any containers from /data/custom/machines to /var/lib/machines.
# Updates the backup .deb files for offline install.

# Wait up to 45 seconds for an active internet connection. Bypasses instantly if already online, or stops waiting after 15 tries if completely offline.
count=0
while [ $count -lt 15 ] && ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; do
    sleep 3
    count=$((count + 1))
done
set -e

# The || true keeps these commands from breaking the script unnecessarily
apt-get --fix-broken install -y || true
apt-get update -qq || true

# Only wipe/download if the ping actually succeeded (count is less than 15)
if [ $count -lt 15 ]; then
    echo "Updating backup dpkg package files..."
    mkdir -p /data/custom/dpkg
    rm -f /data/custom/dpkg/*.deb
    cd /data/custom/dpkg
    apt download systemd-container libnss-mymachines debootstrap arch-test || true
else
    echo "System offline. Preserving existing cached files."
    mkdir -p /data/custom/dpkg
    cd /data/custom/dpkg
fi

# Install systemd-container and dependencies, fall back to cached .deb files if online install fails
if ! dpkg -l systemd-container 2>/dev/null | grep -q '^ii'; then
if ! apt -y install systemd-container debootstrap; then
echo "Online install failed, attempting offline install from cached .deb files..."
dpkg -i /data/custom/dpkg/*.deb 2>/dev/null || apt-get -f install -y
fi
fi

# Link containers from /data/custom/machines to /var/lib/machines
mkdir -p /var/lib/machines
for machine_dir in /data/custom/machines/*/; do
[ -d "$machine_dir" ] || continue
machine=$(basename "$machine_dir")
if [ ! -e "/var/lib/machines/$machine" ]; then
ln -s "/data/custom/machines/$machine" "/var/lib/machines/"
machinectl enable "$machine"
machinectl start "$machine"
fi
done
echo "Setup complete."
