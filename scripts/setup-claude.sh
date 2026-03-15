#!/usr/bin/env bash
# =============================================================================
# Claude Code Authentication Setup
# =============================================================================
set -euo pipefail

echo "=== Claude Code Setup ==="
echo ""

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[!] ANTHROPIC_API_KEY is not set."
    echo "    Set it in .env or export it:"
    echo "    export ANTHROPIC_API_KEY=sk-ant-..."
    echo ""
    echo "    Alternatively, run 'claude' to authenticate interactively."
    echo ""
else
    echo "[OK] ANTHROPIC_API_KEY is configured."
fi

# Verify installation
if command -v claude &>/dev/null; then
    echo "[OK] Claude Code CLI is installed: $(claude --version 2>/dev/null || echo 'available')"
else
    echo "[!] Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

echo ""
echo "To start Claude Code, run: claude"
echo "To configure settings: claude config"
echo ""
