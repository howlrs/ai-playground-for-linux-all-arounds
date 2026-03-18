#!/usr/bin/env bash
set -euo pipefail

AGENTDB_DIR="${HOME}/.agentdb"
AGENTDB_BIND="127.0.0.1:8000"
AGENTDB_USER="root"
AGENTDB_PASS="root"
AGENTDB_LOG="${AGENTDB_DIR}/surreal.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/init-schema.surql"
SCHEMA_MARKER="${AGENTDB_DIR}/.schema_initialized"

mkdir -p "${AGENTDB_DIR}"

# Check if SurrealDB is already running
if curl -sf "http://${AGENTDB_BIND}/health" >/dev/null 2>&1; then
    echo "[agentdb] SurrealDB is already running at ${AGENTDB_BIND}"
    exit 0
fi

echo "[agentdb] Starting SurrealDB at ${AGENTDB_BIND}..."

surreal start "surrealkv://${AGENTDB_DIR}/data" \
    --bind "${AGENTDB_BIND}" \
    --user "${AGENTDB_USER}" \
    --pass "${AGENTDB_PASS}" \
    --log info \
    >"${AGENTDB_LOG}" 2>&1 &

SURREAL_PID=$!
echo "${SURREAL_PID}" > "${AGENTDB_DIR}/surreal.pid"
echo "[agentdb] SurrealDB started with PID ${SURREAL_PID}"

# Wait for SurrealDB to become healthy
echo "[agentdb] Waiting for SurrealDB to be ready..."
elapsed=0
while [ "${elapsed}" -lt 30 ]; do
    if curl -sf "http://${AGENTDB_BIND}/health" >/dev/null 2>&1; then
        echo "[agentdb] SurrealDB is ready (took ${elapsed}s)"
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "${elapsed}" -ge 30 ]; then
    echo "[agentdb] ERROR: SurrealDB failed to start within 30s. Check ${AGENTDB_LOG}" >&2
    exit 1
fi

# Initialize schema if needed
if [ ! -f "${SCHEMA_MARKER}" ] && [ -f "${SCHEMA_FILE}" ]; then
    echo "[agentdb] Initializing schema from ${SCHEMA_FILE}..."
    surreal sql \
        --endpoint "http://${AGENTDB_BIND}" \
        --username "${AGENTDB_USER}" \
        --password "${AGENTDB_PASS}" \
        < "${SCHEMA_FILE}"
    touch "${SCHEMA_MARKER}"
    echo "[agentdb] Schema initialized successfully"
elif [ -f "${SCHEMA_MARKER}" ]; then
    echo "[agentdb] Schema already initialized, skipping"
else
    echo "[agentdb] No schema file found at ${SCHEMA_FILE}, skipping initialization"
fi

echo "[agentdb] SurrealDB is running (PID ${SURREAL_PID}, bind ${AGENTDB_BIND})"
