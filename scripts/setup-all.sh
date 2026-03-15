#!/usr/bin/env bash
# =============================================================================
# AI Playground - Full Setup
# Run this after first container start to verify all tools and auth.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "  AI Playground - Environment Setup"
echo "=============================================="
echo ""

# AI Agents
bash "${SCRIPT_DIR}/setup-claude.sh"
echo "----------------------------------------------"
bash "${SCRIPT_DIR}/setup-gemini.sh"
echo "----------------------------------------------"

# Google Workspace
bash "${SCRIPT_DIR}/setup-gws.sh"
echo "----------------------------------------------"

# Cloud & Platform CLIs
bash "${SCRIPT_DIR}/setup-cloud.sh"
echo "----------------------------------------------"

# Tool versions summary
echo "=== Installed Tool Versions ==="
echo ""
echo "Node.js:  $(node --version 2>/dev/null || echo 'not found')"
echo "npm:      $(npm --version 2>/dev/null || echo 'not found')"
echo "Go:       $(go version 2>/dev/null | awk '{print $3}' || echo 'not found')"
echo "Rust:     $(rustc --version 2>/dev/null || echo 'not found')"
echo "Cargo:    $(cargo --version 2>/dev/null || echo 'not found')"
echo "Python:   $(python3 --version 2>/dev/null || echo 'not found')"
echo "git:      $(git --version 2>/dev/null || echo 'not found')"
echo "gh:       $(gh --version 2>/dev/null | head -1 || echo 'not found')"
echo "glab:     $(glab --version 2>/dev/null | head -1 || echo 'not found')"
echo "gcloud:   $(gcloud --version 2>/dev/null | head -1 || echo 'not found')"
echo "aws:      $(aws --version 2>/dev/null || echo 'not found')"
echo ""
echo "=============================================="
echo "  Setup complete. Run 'claude' to start."
echo "=============================================="
