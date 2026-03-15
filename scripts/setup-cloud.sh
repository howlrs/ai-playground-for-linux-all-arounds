#!/usr/bin/env bash
# =============================================================================
# Cloud & Platform CLI Authentication Setup
# =============================================================================
# ⚠ CAUTION: These commands interact with REAL external services.
#   - gh:     GitHub repos, issues, PRs, Actions
#   - glab:   GitLab repos, issues, MRs, CI/CD
#   - gcloud: Google Cloud resources (billing applies)
#   - aws:    AWS resources (billing applies)
#
# AI agents should NOT run destructive operations with these CLIs
# without explicit user approval.
# =============================================================================
set -euo pipefail

echo "=== Cloud & Platform CLI Setup ==="
echo ""
echo "######################################################"
echo "#  CAUTION: These CLIs access REAL external services  #"
echo "#  with REAL billing and permissions.                  #"
echo "#  Review all operations before executing.             #"
echo "######################################################"
echo ""

# --- GitHub CLI ---
echo "--- GitHub CLI (gh) ---"
if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "[OK] GitHub token is configured via environment variable."
else
    echo "[!] No GitHub token found."
    echo "    Option 1: export GH_TOKEN=ghp_..."
    echo "    Option 2: gh auth login"
fi
echo ""

# --- GitLab CLI ---
echo "--- GitLab CLI (glab) ---"
if [ -n "${GITLAB_TOKEN:-}" ]; then
    echo "[OK] GitLab token is configured via environment variable."
else
    echo "[!] No GitLab token found."
    echo "    Option 1: export GITLAB_TOKEN=glpat-..."
    echo "    Option 2: glab auth login"
fi
echo ""

# --- Google Cloud ---
echo "--- Google Cloud (gcloud) ---"
if [ -f "${HOME}/.config/gcloud/application_default_credentials.json" ] 2>/dev/null; then
    echo "[OK] gcloud credentials found."
    gcloud config list account --format="value(core.account)" 2>/dev/null && true
else
    echo "[!] No gcloud credentials found."
    echo "    Option 1: Mount host credentials via compose.yaml volume"
    echo "    Option 2: gcloud auth login --no-launch-browser"
    echo "    Option 3: gcloud auth application-default login --no-launch-browser"
fi
echo ""

# --- AWS CLI ---
echo "--- AWS CLI ---"
if [ -n "${AWS_ACCESS_KEY_ID:-}" ] || [ -f "${HOME}/.aws/credentials" ]; then
    echo "[OK] AWS credentials found."
    aws sts get-caller-identity --output text 2>/dev/null && true
else
    echo "[!] No AWS credentials found."
    echo "    Option 1: Mount host ~/.aws via compose.yaml volume"
    echo "    Option 2: export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=..."
    echo "    Option 3: aws configure"
fi
echo ""
