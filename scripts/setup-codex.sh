#!/usr/bin/env bash
# =============================================================================
# OpenAI Codex CLI Authentication Setup
# =============================================================================
set -euo pipefail

echo "=== OpenAI Codex Setup ==="
echo ""

if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "[!] OPENAI_API_KEY is not set."
    echo "    Set it in .env or export it:"
    echo "    export OPENAI_API_KEY=sk-..."
    echo ""
else
    echo "[OK] OPENAI_API_KEY is configured."
fi

# Verify installation
if command -v codex &>/dev/null; then
    echo "[OK] Codex CLI is installed."
else
    echo "[!] Codex CLI not found. Install with: npm install -g @openai/codex"
    exit 1
fi

echo ""
echo "To start Codex, run: codex"
echo ""
