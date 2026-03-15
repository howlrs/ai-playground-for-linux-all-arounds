#!/usr/bin/env bash
# =============================================================================
# Gemini CLI Authentication Setup
# =============================================================================
set -euo pipefail

echo "=== Gemini CLI Setup ==="
echo ""

if [ -z "${GEMINI_API_KEY:-}" ]; then
    echo "[!] GEMINI_API_KEY is not set."
    echo "    Set it in .env or export it:"
    echo "    export GEMINI_API_KEY=AI..."
    echo ""
    echo "    Get your key at: https://aistudio.google.com/apikey"
    echo ""
else
    echo "[OK] GEMINI_API_KEY is configured."
fi

# Verify installation
if command -v gemini &>/dev/null; then
    echo "[OK] Gemini CLI is installed."
else
    echo "[!] Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
    exit 1
fi

echo ""
echo "To start Gemini CLI, run: gemini"
echo ""
