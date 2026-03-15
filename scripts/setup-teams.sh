#!/usr/bin/env bash
# =============================================================================
# Microsoft Teams / Microsoft 365 CLI Setup
# =============================================================================
# ⚠ CAUTION: m365 CLI can read/write Teams messages, channels, and other
#   Microsoft 365 resources. Use read operations freely; write operations
#   require explicit user approval.
# =============================================================================
set -euo pipefail

echo "=== Microsoft Teams (M365 CLI) Setup ==="
echo ""

# Verify installation
if command -v m365 &>/dev/null; then
    echo "[OK] CLI for Microsoft 365 is installed."
else
    echo "[!] m365 CLI not found. Install with: npm install -g @pnp/cli-microsoft365"
    exit 1
fi

echo ""
echo "Authentication options:"
echo ""
echo "  1. Interactive (device code flow):"
echo "     m365 login"
echo "     → Opens a URL to authenticate via browser on another device"
echo ""
echo "  2. Non-interactive (client secret - for Docker/CI):"
echo "     m365 login --authType secret \\"
echo "       --appId \$M365_APP_ID \\"
echo "       --tenant \$M365_TENANT_ID \\"
echo "       --secret \$M365_APP_SECRET"
echo ""
echo "  Required Entra ID app permissions:"
echo "    - ChannelMessage.Read.All"
echo "    - Chat.Read / Chat.Read.All"
echo "    - Team.ReadBasic.All"
echo "    - User.Read"
echo ""

# Check if already logged in
if m365 status 2>/dev/null | grep -q "Logged in"; then
    echo "[OK] Already logged in to Microsoft 365."
    m365 status
else
    echo "[!] Not logged in. Run 'm365 login' to authenticate."
fi

echo ""
echo "Common Teams commands:"
echo "  m365 teams team list                         # List your teams"
echo "  m365 teams channel list --teamId <id>        # List channels"
echo "  m365 teams message list --teamId <id> \\      # Read messages"
echo "    --channelId <id>"
echo "  m365 teams chat message list --chatId <id>   # Read chat messages"
echo ""
echo "Python (msgraph-sdk) is also available for programmatic access."
echo "  Example: uv run python -c 'import msgraph; print(\"OK\")'"
echo ""
