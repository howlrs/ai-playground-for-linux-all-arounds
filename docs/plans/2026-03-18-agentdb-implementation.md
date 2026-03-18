# AgentDB Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** SurrealDB ベースのマルチエージェント集合知基盤を playground コンテナに導入する

**Architecture:** 単一コンテナ内で SurrealDB をバックグラウンドプロセスとして起動。Namespace `agents` 配下に `logs`（TTL 14日）と `knowledge`（永続）の2 DBを配置。エージェントは `agentdb` CLIラッパー経由でアクセスする。

**Tech Stack:** SurrealDB v3.x, Bash (CLI wrapper), cron (TTL cleanup)

---

### Task 1: SurrealDB スキーマ定義ファイル

**Files:**
- Create: `scripts/init-schema.surql`

**Step 1: スキーマファイルを作成**

```surql
-- =============================================================================
-- AgentDB Schema Definition
-- Namespace: agents | Databases: logs, knowledge
-- =============================================================================

-- =============================================
-- DB: logs (TTL 14d - ephemeral event data)
-- =============================================
USE NS agents DB logs;

DEFINE TABLE event SCHEMALESS;
DEFINE FIELD agent      ON event TYPE string;
DEFINE FIELD type       ON event TYPE string;
DEFINE FIELD data       ON event FLEXIBLE TYPE object;
DEFINE FIELD tags       ON event TYPE option<array<string>>;
DEFINE FIELD created_at ON event TYPE datetime DEFAULT time::now();

DEFINE INDEX idx_event_agent ON event FIELDS agent;
DEFINE INDEX idx_event_type  ON event FIELDS type;
DEFINE INDEX idx_event_time  ON event FIELDS created_at;

-- =============================================
-- DB: knowledge (persistent collective intelligence)
-- =============================================
USE NS agents DB knowledge;

DEFINE TABLE entry SCHEMALESS;
DEFINE FIELD agent      ON entry TYPE string;
DEFINE FIELD kind       ON entry TYPE string;
DEFINE FIELD domain     ON entry TYPE option<string>;
DEFINE FIELD title      ON entry TYPE string;
DEFINE FIELD body       ON entry TYPE string;
DEFINE FIELD data       ON entry FLEXIBLE TYPE object;
DEFINE FIELD tags       ON entry TYPE option<array<string>>;
DEFINE FIELD created_at ON entry TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON entry TYPE datetime DEFAULT time::now();

DEFINE INDEX idx_entry_agent  ON entry FIELDS agent;
DEFINE INDEX idx_entry_kind   ON entry FIELDS kind;
DEFINE INDEX idx_entry_domain ON entry FIELDS domain;

DEFINE TABLE relates_to SCHEMALESS;
DEFINE FIELD relation   ON relates_to TYPE string;
DEFINE FIELD created_at ON relates_to TYPE datetime DEFAULT time::now();
```

**Step 2: Commit**

```bash
git add scripts/init-schema.surql
git commit -m "feat(agentdb): add SurrealDB schema definition for logs and knowledge DBs"
```

---

### Task 2: SurrealDB 起動スクリプト

**Files:**
- Create: `scripts/start-surreal.sh`

**Step 1: 起動スクリプトを作成**

```bash
#!/usr/bin/env bash
# =============================================================================
# AgentDB - SurrealDB startup script
# Starts SurrealDB in background and initializes schema if first run.
# =============================================================================
set -euo pipefail

AGENTDB_DIR="${HOME}/.agentdb"
AGENTDB_BIND="127.0.0.1:8000"
AGENTDB_USER="root"
AGENTDB_PASS="root"
AGENTDB_LOG="${AGENTDB_DIR}/surreal.log"
SCHEMA_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/init-schema.surql"
SCHEMA_MARKER="${AGENTDB_DIR}/.schema_initialized"

mkdir -p "${AGENTDB_DIR}"

# Check if already running
if curl -sf "http://${AGENTDB_BIND}/health" > /dev/null 2>&1; then
    echo "[agentdb] SurrealDB is already running on ${AGENTDB_BIND}"
    exit 0
fi

# Start SurrealDB in background
echo "[agentdb] Starting SurrealDB..."
surreal start "surrealkv://${AGENTDB_DIR}/data" \
    --bind "${AGENTDB_BIND}" \
    --user "${AGENTDB_USER}" \
    --pass "${AGENTDB_PASS}" \
    --log info \
    > "${AGENTDB_LOG}" 2>&1 &

SURREAL_PID=$!
echo "${SURREAL_PID}" > "${AGENTDB_DIR}/surreal.pid"

# Wait for SurrealDB to be ready
echo "[agentdb] Waiting for SurrealDB to be ready..."
for i in $(seq 1 30); do
    if curl -sf "http://${AGENTDB_BIND}/health" > /dev/null 2>&1; then
        echo "[agentdb] SurrealDB is ready (PID: ${SURREAL_PID})"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[agentdb] ERROR: SurrealDB failed to start. Check ${AGENTDB_LOG}"
        exit 1
    fi
    sleep 1
done

# Initialize schema (only on first run)
if [ ! -f "${SCHEMA_MARKER}" ] && [ -f "${SCHEMA_FILE}" ]; then
    echo "[agentdb] Initializing schema..."
    surreal sql \
        --endpoint "http://${AGENTDB_BIND}" \
        --username "${AGENTDB_USER}" \
        --password "${AGENTDB_PASS}" \
        < "${SCHEMA_FILE}"
    touch "${SCHEMA_MARKER}"
    echo "[agentdb] Schema initialized."
fi

echo "[agentdb] AgentDB is running. Data dir: ${AGENTDB_DIR}/data"
```

**Step 2: Commit**

```bash
git add scripts/start-surreal.sh
git commit -m "feat(agentdb): add SurrealDB startup script with schema initialization"
```

---

### Task 3: agentdb CLI ラッパー

**Files:**
- Create: `scripts/agentdb`

**Step 1: CLI ラッパーを作成**

```bash
#!/usr/bin/env bash
# =============================================================================
# agentdb - CLI wrapper for AgentDB (SurrealDB)
# Usage: agentdb <command> [args...]
# =============================================================================
set -euo pipefail

AGENTDB_BIND="${AGENTDB_BIND:-127.0.0.1:8000}"
AGENTDB_USER="${AGENTDB_USER:-root}"
AGENTDB_PASS="${AGENTDB_PASS:-root}"
AGENTDB_NS="agents"
AGENTDB_AGENT="${AGENTDB_AGENT:-unknown}"

# --- helpers ---

_sql() {
    local db="$1"
    shift
    surreal sql \
        --endpoint "http://${AGENTDB_BIND}" \
        --username "${AGENTDB_USER}" \
        --password "${AGENTDB_PASS}" \
        --namespace "${AGENTDB_NS}" \
        --database "${db}" \
        "$@"
}

_sql_exec() {
    local db="$1"
    local query="$2"
    echo "${query}" | _sql "${db}"
}

_usage() {
    cat <<'USAGE'
agentdb - Multi-agent collective intelligence CLI

Usage: agentdb <command> [args...]

Commands (logs DB - TTL 14d):
  log <type> <data_json>                   Record an event
  search <keyword> [options]               Search events
    --type <type>       Filter by event type
    --agent <agent>     Filter by agent
    --since <duration>  Time range (e.g. 7d, 24h)
    --limit <n>         Max results (default: 20)

Commands (knowledge DB - persistent):
  save <kind> <title> <body> [options]     Save knowledge entry
    --domain <domain>   Technical domain
    --tags <t1,t2,...>  Comma-separated tags
  find <keyword> [options]                 Search knowledge
    --kind <kind>       Filter by kind
    --agent <agent>     Filter by agent
    --domain <domain>   Filter by domain
    --limit <n>         Max results (default: 20)
  relate <from_id> <relation> <to_id>      Create graph relation

Common:
  query <surql> [--db logs|knowledge]      Execute raw SurrealQL
  status                                   Show DB status
  cleanup                                  Delete events older than 14 days

Environment:
  AGENTDB_AGENT   Your agent name (default: unknown)
  AGENTDB_BIND    SurrealDB address (default: 127.0.0.1:8000)
USAGE
}

# --- commands ---

cmd_log() {
    local type="${1:?Usage: agentdb log <type> <data_json>}"
    local data="${2:?Usage: agentdb log <type> <data_json>}"
    local query="CREATE event SET agent = '${AGENTDB_AGENT}', type = '${type}', data = ${data}, created_at = time::now();"
    _sql_exec "logs" "${query}"
}

cmd_search() {
    local keyword="${1:?Usage: agentdb search <keyword> [--type TYPE] [--agent AGENT] [--since DURATION] [--limit N]}"
    shift
    local type="" agent="" since="" limit="20"
    while [ $# -gt 0 ]; do
        case "$1" in
            --type)  type="$2";  shift 2 ;;
            --agent) agent="$2"; shift 2 ;;
            --since) since="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local where="string::lowercase(data) CONTAINS string::lowercase('${keyword}')"
    [ -n "${type}" ]  && where="${where} AND type = '${type}'"
    [ -n "${agent}" ] && where="${where} AND agent = '${agent}'"
    [ -n "${since}" ] && where="${where} AND created_at > time::now() - ${since}"

    _sql_exec "logs" "SELECT * FROM event WHERE ${where} ORDER BY created_at DESC LIMIT ${limit};"
}

cmd_save() {
    local kind="${1:?Usage: agentdb save <kind> <title> <body> [--domain D] [--tags t1,t2]}"
    local title="${2:?Usage: agentdb save <kind> <title> <body>}"
    local body="${3:?Usage: agentdb save <kind> <title> <body>}"
    shift 3
    local domain="NONE" tags="NONE"
    while [ $# -gt 0 ]; do
        case "$1" in
            --domain) domain="'$2'"; shift 2 ;;
            --tags)   tags="[$(echo "$2" | sed "s/[^,]*/'\0'/g")]"; shift 2 ;;
            *) shift ;;
        esac
    done

    local query="CREATE entry SET agent = '${AGENTDB_AGENT}', kind = '${kind}', title = '${title}', body = '${body}', domain = ${domain}, tags = ${tags}, created_at = time::now(), updated_at = time::now();"
    _sql_exec "knowledge" "${query}"
}

cmd_find() {
    local keyword="${1:?Usage: agentdb find <keyword> [--kind KIND] [--agent AGENT] [--domain DOMAIN] [--limit N]}"
    shift
    local kind="" agent="" domain="" limit="20"
    while [ $# -gt 0 ]; do
        case "$1" in
            --kind)   kind="$2";   shift 2 ;;
            --agent)  agent="$2";  shift 2 ;;
            --domain) domain="$2"; shift 2 ;;
            --limit)  limit="$2";  shift 2 ;;
            *) shift ;;
        esac
    done

    local where="(string::lowercase(title) CONTAINS string::lowercase('${keyword}') OR string::lowercase(body) CONTAINS string::lowercase('${keyword}'))"
    [ -n "${kind}" ]   && where="${where} AND kind = '${kind}'"
    [ -n "${agent}" ]  && where="${where} AND agent = '${agent}'"
    [ -n "${domain}" ] && where="${where} AND domain = '${domain}'"

    _sql_exec "knowledge" "SELECT * FROM entry WHERE ${where} ORDER BY created_at DESC LIMIT ${limit};"
}

cmd_relate() {
    local from_id="${1:?Usage: agentdb relate <from_id> <relation> <to_id>}"
    local relation="${2:?Usage: agentdb relate <from_id> <relation> <to_id>}"
    local to_id="${3:?Usage: agentdb relate <from_id> <relation> <to_id>}"
    _sql_exec "knowledge" "RELATE ${from_id}->relates_to->${to_id} SET relation = '${relation}', created_at = time::now();"
}

cmd_query() {
    local query="${1:?Usage: agentdb query <surql> [--db logs|knowledge]}"
    shift
    local db="logs"
    while [ $# -gt 0 ]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    _sql_exec "${db}" "${query}"
}

cmd_status() {
    echo "=== AgentDB Status ==="
    if curl -sf "http://${AGENTDB_BIND}/health" > /dev/null 2>&1; then
        echo "SurrealDB: running (${AGENTDB_BIND})"
    else
        echo "SurrealDB: NOT running"
        return 1
    fi
    echo ""
    echo "--- logs DB (TTL 14d) ---"
    _sql_exec "logs" "SELECT count() AS total FROM event GROUP ALL;" 2>/dev/null || echo "  (empty)"
    echo ""
    echo "--- knowledge DB (persistent) ---"
    _sql_exec "knowledge" "SELECT count() AS total FROM entry GROUP ALL;" 2>/dev/null || echo "  (empty)"
}

cmd_cleanup() {
    echo "[agentdb] Cleaning up events older than 14 days..."
    _sql_exec "logs" "DELETE FROM event WHERE created_at < time::now() - 14d;"
    echo "[agentdb] Cleanup complete."
}

# --- main ---

case "${1:-help}" in
    log)     shift; cmd_log "$@" ;;
    search)  shift; cmd_search "$@" ;;
    save)    shift; cmd_save "$@" ;;
    find)    shift; cmd_find "$@" ;;
    relate)  shift; cmd_relate "$@" ;;
    query)   shift; cmd_query "$@" ;;
    status)  cmd_status ;;
    cleanup) cmd_cleanup ;;
    help|-h|--help) _usage ;;
    *)       echo "Unknown command: $1"; _usage; exit 1 ;;
esac
```

**Step 2: Commit**

```bash
git add scripts/agentdb
git commit -m "feat(agentdb): add CLI wrapper for multi-agent DB access"
```

---

### Task 4: TTL クリーンアップスクリプト

**Files:**
- Create: `scripts/agentdb-cleanup.sh`

**Step 1: クリーンアップスクリプトを作成**

```bash
#!/usr/bin/env bash
# =============================================================================
# AgentDB - TTL cleanup (designed for cron)
# Deletes events older than 14 days from the logs database.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/agentdb" cleanup
```

**Step 2: Commit**

```bash
git add scripts/agentdb-cleanup.sh
git commit -m "feat(agentdb): add TTL cleanup script for cron"
```

---

### Task 5: Dockerfile に SurrealDB を追加

**Files:**
- Modify: `Dockerfile:150-160` (after Superpowers plugin section)

**Step 1: Dockerfile に SurrealDB インストールセクションを追加**

`Dockerfile` の Section 14 (Superpowers) と Section 15 (Setup scripts) の間に以下を挿入:

```dockerfile
# ---------------------------------------------------------------------------
# 14.5. SurrealDB (AgentDB - multi-agent collective intelligence)
# ---------------------------------------------------------------------------
RUN curl -sSf https://install.surrealdb.com | sh
```

また、Section 15 の後（`RUN chmod +x` の行の後）に agentdb を PATH に入れるための行を追加:

```dockerfile
# Make agentdb available in PATH
RUN ln -s ${HOME}/scripts/agentdb ${HOME}/.local/bin/agentdb
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat(agentdb): add SurrealDB installation to Dockerfile"
```

---

### Task 6: compose.yaml にボリューム追加

**Files:**
- Modify: `compose.yaml:17-31` (volumes section in service)
- Modify: `compose.yaml:53-58` (named volumes)

**Step 1: サービスの volumes に agentdb-data を追加**

`compose.yaml` のサービス volumes セクション（line 30 付近、m365-config の後）に追加:

```yaml
      # Persist AgentDB data across rebuilds
      - agentdb-data:/home/dev/.agentdb
```

named volumes セクション（末尾）に追加:

```yaml
  agentdb-data:
```

**Step 2: Commit**

```bash
git add compose.yaml
git commit -m "feat(agentdb): add persistent volume for SurrealDB data"
```

---

### Task 7: setup-all.sh に SurrealDB 起動を追加

**Files:**
- Modify: `scripts/setup-all.sh:33-54`

**Step 1: Cloud セクションの後、Tool versions の前に SurrealDB 起動を追加**

Line 33 (`bash "${SCRIPT_DIR}/setup-cloud.sh"`) の後に追加:

```bash
echo "----------------------------------------------"

# AgentDB (SurrealDB)
echo "=== AgentDB Setup ==="
bash "${SCRIPT_DIR}/start-surreal.sh"
```

Tool versions セクション（line 50 付近）に SurrealDB バージョン表示を追加:

```bash
echo "surreal:  $(surreal version 2>/dev/null || echo 'not found')"
```

**Step 2: Commit**

```bash
git add scripts/setup-all.sh
git commit -m "feat(agentdb): integrate SurrealDB startup into setup-all.sh"
```

---

### Task 8: 活用方針ドキュメント (docs/AGENTDB.md)

**Files:**
- Create: `docs/AGENTDB.md`

**Step 1: ドキュメントを作成**

```markdown
# AgentDB — マルチエージェント集合知基盤

## 目的

AgentDB は、複数のAI・エージェントが会話・実行ログ・知見・意思決定を
**共有情報として永続化**し、各々の視座と専門性から集合知を構築するための基盤である。

エージェントが大量にアサインされた場合でも、過去の試行錯誤・発見・判断の履歴を
共有DBを通じて参照でき、集団としての知識が蓄積・活用される。

## アーキテクチャ

```
Namespace: agents
├── DB: logs (TTL 14日)
│   └── Table: event (SCHEMALESS)
│       会話、ツール実行、QAレビュー、エラー、メモなど
│
└── DB: knowledge (永続)
    ├── Table: entry (SCHEMALESS)
    │   知見、意思決定、パターン、参照、教訓など
    │
    └── Table: relates_to (グラフリレーション)
        知見間の関係: builds_on, contradicts, supports, derives_from
```

## CLI リファレンス

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AGENTDB_AGENT` | `unknown` | あなたのエージェント名。**必ず設定すること** |
| `AGENTDB_BIND` | `127.0.0.1:8000` | SurrealDB アドレス |

各エージェントは起動時に `AGENTDB_AGENT` を設定する:
- Claude Code: `export AGENTDB_AGENT=claude`
- Gemini CLI: `export AGENTDB_AGENT=gemini`
- Codex: `export AGENTDB_AGENT=codex`
- カスタムエージェント: `export AGENTDB_AGENT=<your-name>`

### logs DB — イベント記録

```bash
# 会話を記録
agentdb log conversation '{"session_id":"abc123","context":"認証実装","summary":"OAuth2フローの設計を議論"}'

# ツール実行を記録
agentdb log tool_exec '{"cmd":"npm test","exit_code":0,"duration_ms":3200}'

# QAレビュー結果を記録
agentdb log qa_review '{"target_agent":"claude","review_type":"code","findings":[{"severity":"important","description":"N+1クエリ"}]}'

# エラーを記録
agentdb log error '{"error_type":"build","message":"TypeScript compilation failed","resolution":"missing type import"}'

# 一時メモ
agentdb log note '{"content":"この設計パターンは後で再検討が必要"}'
```

### logs DB — 検索

```bash
# キーワード検索
agentdb search "認証"

# 条件付き検索
agentdb search "テスト" --type qa_review --agent gemini --since 7d

# 直近のエラーを確認
agentdb search "error" --type error --since 24h --limit 5
```

### knowledge DB — 知見の記録

```bash
# 知見を保存
agentdb save insight "SurrealDBはネイティブTTL非対応" \
  "cronジョブで14日超のレコードを日次削除する設計とした" \
  --domain database --tags "surrealdb,ttl,design-decision"

# 意思決定を記録
agentdb save decision "認証方式にOAuth2を採用" \
  "セッショントークンのコンプライアンス要件を満たすため、OAuth2 + PKCE を選択" \
  --domain auth --tags "oauth2,compliance"

# パターンを記録
agentdb save pattern "Geminiは型安全性の指摘が鋭い" \
  "コードレビューでGeminiが指摘する型関連の問題は高確率で実際のバグに繋がる" \
  --tags "gemini,qa,observation"

# 教訓を記録
agentdb save lesson "モックテストとDBの乖離に注意" \
  "モックが通ってもprodマイグレーションが失敗した事例あり。統合テストを優先すべき" \
  --domain testing --tags "testing,database,incident"
```

### knowledge DB — 検索

```bash
# キーワード検索
agentdb find "認証"

# 条件付き検索
agentdb find "セキュリティ" --kind insight --agent gemini --domain auth
```

### グラフリレーション

```bash
# 知見Aが知見Bの発展であることを記録
agentdb relate entry:abc builds_on entry:xyz

# 知見Aが知見Bと矛盾することを記録
agentdb relate entry:abc contradicts entry:xyz

# 知見Aが意思決定Bの根拠であることを記録
agentdb relate entry:abc supports entry:def
```

### 生 SurrealQL

```bash
# logs DB に対して
agentdb query "SELECT * FROM event WHERE type = 'error' ORDER BY created_at DESC LIMIT 5;" --db logs

# knowledge DB に対して
agentdb query "SELECT * FROM entry WHERE domain = 'auth';" --db knowledge

# グラフ辿り
agentdb query "SELECT <-relates_to<-entry FROM entry:target_id;" --db knowledge
```

### ステータス確認

```bash
agentdb status
```

## エージェント向け活用ガイドライン

### いつ logs に記録するか

- **会話の要約**: セッション終了時に会話の要点を記録する
- **重要なツール実行**: テスト実行、ビルド、デプロイなど結果を残すべき操作
- **QAレビュー結果**: Gemini CLI からのレビュー結果
- **エラーと解決策**: 発生したエラーとその解決方法
- **一時的なメモ**: 後で参照したいが永続化するほどではない情報

### いつ knowledge に昇格させるか

- **繰り返し参照される知見**: 複数回 logs から同じ情報を探した場合
- **意思決定の記録**: なぜその選択をしたのか、将来の判断に影響する場合
- **パターンの発見**: 複数の事象から見出された法則性
- **教訓**: 失敗や成功から得られた、再利用可能な学び

### 他エージェントの知見を参照する

作業開始時に、関連ドメインの知見を確認する習慣をつける:

```bash
# 自分が担当するドメインの既存知見を確認
agentdb find "" --domain <your-domain>

# 他のエージェントの最近の活動を確認
agentdb search "" --agent <agent-name> --since 3d

# 特定テーマの意思決定履歴を確認
agentdb find "<theme>" --kind decision
```

### relates_to の活用

知見は孤立させず、関係性を記録する:

- **builds_on**: 既存の知見を発展させた場合
- **contradicts**: 異なる結論に達した場合（対立は価値がある）
- **supports**: 意思決定の根拠として知見を引用する場合
- **derives_from**: ログから知見を抽出した場合

## 運用

### バックアップ

```bash
# knowledge DB のエクスポート（定期的に推奨）
surreal export --conn http://127.0.0.1:8000 \
  --user root --pass root \
  --ns agents --db knowledge \
  knowledge-backup.surql
```

### TTL クリーンアップ

logs DB のイベントは14日で自動削除される（日次 cron）。
手動実行: `agentdb cleanup`

### トラブルシューティング

```bash
# SurrealDB が起動しているか確認
agentdb status

# ログを確認
cat ~/.agentdb/surreal.log

# 手動で再起動
bash ~/scripts/start-surreal.sh
```
```

**Step 2: Commit**

```bash
git add docs/AGENTDB.md
git commit -m "docs(agentdb): add comprehensive usage guide and agent guidelines"
```

---

### Task 9: CLAUDE.md に agentdb セクション追加

**Files:**
- Modify: `CLAUDE.md:95-96` (搭載ツール セクションの直前)

**Step 1: `## 搭載ツール` の直前に AgentDB セクションを挿入**

```markdown
## AgentDB — 集合知基盤

本環境には SurrealDB ベースの共有データベース AgentDB が搭載されている。
すべてのエージェントが `agentdb` CLI を通じて情報を共有する。

### 基本ルール

- `AGENTDB_AGENT=claude` を設定してから使用する
- 作業開始時に `agentdb find "" --domain <担当ドメイン>` で既存知見を確認する
- 重要な意思決定は `agentdb save decision` で記録する
- QAレビュー結果は `agentdb log qa_review` で記録する
- 詳細は `docs/AGENTDB.md` を参照

### クイックリファレンス

```bash
# イベント記録（14日で自動削除）
agentdb log <type> '<json>'

# 知見の永続化
agentdb save <kind> "<title>" "<body>" [--domain D] [--tags t1,t2]

# 検索
agentdb search "<keyword>" --since 7d    # logs
agentdb find "<keyword>" --kind insight   # knowledge
```

```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add AgentDB section to CLAUDE.md"
```

---

### Task 10: AGENTS.md に共有DB利用ルール追加

**Files:**
- Modify: `AGENTS.md:189-190` (末尾)

**Step 1: ファイル末尾に AgentDB セクションを追加**

```markdown

## AgentDB — 共有知識基盤

すべてのエージェントは AgentDB を通じて情報を共有する。

### 共通ルール

1. **`AGENTDB_AGENT` を必ず設定** — 記録の帰属を明確にする
2. **作業前に既存知見を確認** — 他エージェントの知見を踏まえて作業する
3. **意思決定は記録** — なぜその判断をしたか、将来のエージェントのために残す
4. **矛盾を恐れない** — 異なる結論は `contradicts` リレーションで記録する。対立は集合知の価値

### エージェント別の記録責務

| エージェント | 記録すべき内容 |
|------------|---------------|
| Claude Code | 設計判断、実装上の発見、エラーと解決策 |
| Gemini CLI | QAレビュー結果、セキュリティ/品質の知見 |
| Codex | 作業完了報告、発見した問題 |
| 専門エージェント | 担当ドメインの知見、パターン、教訓 |

### データフロー

```
エージェント作業中 → agentdb log (logs DB, TTL 14d)
                         │
                         ▼ 重要な発見があれば昇格
                    agentdb save (knowledge DB, 永続)
                         │
                         ▼ 関連する知見があれば接続
                    agentdb relate (グラフリレーション)
```

詳細: `docs/AGENTDB.md`
```

**Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add AgentDB shared knowledge rules to AGENTS.md"
```

---

### Task 11: GEMINI.md に DB 記録ガイド追加

**Files:**
- Modify: `GEMINI.md:88-89` (末尾)

**Step 1: ファイル末尾に AgentDB セクションを追加**

```markdown

## AgentDB 連携

レビュー結果を AgentDB に記録し、他エージェントと知見を共有する。

### レビュー結果の記録

Claude Code がレビュー依頼時に、結果を AgentDB へ記録する。
Gemini CLI 自身は直接 DB にアクセスしない（`-p` モードのため）。

Claude Code は Gemini CLI のレビュー結果を受け取った後、以下を実行する:

```bash
export AGENTDB_AGENT=gemini
agentdb log qa_review '{"target_agent":"claude","review_type":"code","findings":[...]}'
```

Critical/Important な知見が含まれる場合は knowledge に昇格:

```bash
agentdb save insight "<タイトル>" "<詳細>" --domain <domain> --tags "qa,gemini"
```
```

**Step 2: Commit**

```bash
git add GEMINI.md
git commit -m "docs: add AgentDB integration guide to GEMINI.md"
```

---

### Task 12: 動作検証

**Step 1: SurrealDB のインストール確認（ローカルで可能なら）**

```bash
surreal version
```

**Step 2: スクリプトの構文チェック**

```bash
bash -n scripts/start-surreal.sh
bash -n scripts/agentdb
bash -n scripts/agentdb-cleanup.sh
```

**Step 3: SurrealDB 起動テスト（Docker ビルド後）**

```bash
bash scripts/start-surreal.sh
agentdb status
```

**Step 4: 基本操作テスト**

```bash
export AGENTDB_AGENT=claude

# logs に記録
agentdb log note '{"content":"AgentDB integration test"}'

# logs を検索
agentdb search "test"

# knowledge に保存
agentdb save insight "AgentDB動作確認完了" "初回テストが正常に完了した" --domain infra

# knowledge を検索
agentdb find "AgentDB"

# ステータス
agentdb status
```

**Step 5: Commit（全ファイルの最終確認後）**

```bash
git add -A
git commit -m "feat(agentdb): complete AgentDB integration - multi-agent collective intelligence DB"
```
