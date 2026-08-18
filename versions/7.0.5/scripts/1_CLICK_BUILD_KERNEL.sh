#!/usr/bin/env bash
# ==============================================================================
# 🦍 1-CLICK GORILLA KERNEL BUILDER
# ==============================================================================
# This script autonomously triggers the main kernel build engine.
# No interactive prompts will block the execution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo "🚀 Initiating 1-Click Autonomous Kernel Build..."

# Run the master script
bash "${SCRIPT_DIR}/ULTIMATE_GORILLA_KERNEL.sh"

echo "✅ 1-Click execution finished."
