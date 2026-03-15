#!/usr/bin/env bash
# =============================================================================
# Google Workspace CLI (gws) Authentication Setup
# =============================================================================
set -euo pipefail

echo "=== Google Workspace CLI Setup ==="
echo ""

# Verify installation
if command -v gws &>/dev/null; then
    echo "[OK] Google Workspace CLI is installed."
else
    echo "[!] gws not found. Install with: npm install -g @googleworkspace/cli"
    exit 1
fi

echo ""
echo "Authentication options:"
echo ""
echo "  1. Interactive (requires gcloud):"
echo "     gws auth setup"
echo ""
echo "  2. Service Account:"
echo "     export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/service-account.json"
echo ""
echo "  3. Pre-obtained token:"
echo "     export GOOGLE_WORKSPACE_CLI_TOKEN=ya29...."
echo ""
echo "NOTE: For multi-account access, you can configure multiple"
echo "      OAuth clients or service accounts per Google Workspace domain."
echo ""

# If gcloud is authenticated, offer automated setup
if command -v gcloud &>/dev/null && gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1 | grep -q '@'; then
    echo "[INFO] gcloud is authenticated. You can run 'gws auth setup' for automated OAuth."
fi

echo ""
