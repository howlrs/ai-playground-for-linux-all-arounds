#!/usr/bin/env bash
# =============================================================================
# AgentDB - TTL cleanup (designed for cron)
# Deletes events older than 14 days from the logs database.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/agentdb" cleanup
