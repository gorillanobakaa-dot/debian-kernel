#!/usr/bin/env bash
set -euo pipefail
echo "🦍 Gorilla Kernel 1-Click Installer"
echo "===================================="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "${SCRIPT_DIR}"
echo "📦 Installing Kernel Packages separately..."
sudo dpkg -i *.deb
echo "🔧 Applying 20Gbps Network Tunings..."
sudo cp 99-gorilla-20gbps.conf /etc/sysctl.d/
sudo sysctl --system
echo "🏁 DONE. Please reboot your machine to activate the Gorilla Kernel."
