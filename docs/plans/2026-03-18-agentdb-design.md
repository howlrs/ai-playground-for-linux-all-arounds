# AgentDB 設計書 — マルチエージェント集合知基盤

**日付**: 2026-03-18
**ステータス**: 承認済み

## 1. 目的

複数のAI・エージェント（Claude Code, Gemini CLI, OpenAI Codex、および将来の専門エージェント群）が、
会話・実行ログ・知見・意思決定を **共有情報として永続化** し、各々の視座と専門性から集合知を構築するための基盤。

### 解決する課題

- エージェントの会話やアウトプットが揮発的で、セッション間で失われる
- あるエージェントの知見を別のエージェントが参照できない
- 試行錯誤の履歴が残らず、同じ失敗を繰り返す
- 多数の専門エージェントがアサインされた際の情報共有手段がない

## 2. 技術選定

**SurrealDB v3.x** を採用。

| 評価軸 | SurrealDB |
|--------|-----------|
| ストレージ | SurrealKV（ファイルベース、単一バイナリ） |
| アクセス方法 | CLI (`surreal sql`) + REST API (内蔵) |
| スキーマ | SCHEMALESS対応 — 柔軟な構造化データ |
| グラフ機能 | ネイティブ対応 — 知見間の関係を表現 |
| 複数DB | 1インスタンスで Namespace/Database を分離可能 |
| 運用コスト | 単一バイナリ、同一コンテナに同居 |

## 3. アーキテクチャ

```
playground コンテナ
┌─────────────────────────────────────────────────────┐
│                                                       │
│  surreal start surrealkv:///home/dev/.agentdb         │
│  --bind 127.0.0.1:8000 --user root --pass root       │
│  (バックグラウンドプロセス)                              │
│                                                       │
│  Namespace: agents                                    │
│  ┌────────────────────┐  ┌─────────────────────┐     │
│  │ DB: logs           │  │ DB: knowledge       │     │
│  │ TTL: 14日          │  │ 永続                 │     │
│  │                    │  │                     │     │
│  │ Table: event       │  │ Table: entry        │     │
│  │ (SCHEMALESS)       │  │ (SCHEMALESS)        │     │
│  │                    │  │                     │     │
│  │ 会話, ツール実行,   │  │ 知見, 意思決定,      │     │
│  │ QAレビュー, エラー, │  │ パターン, 参照,      │     │
│  │ メモ               │  │ レッスン             │     │
│  └────────────────────┘  │                     │     │
│                          │ Table: relates_to   │     │
│                          │ (グラフリレーション)   │     │
│                          └─────────────────────┘     │
│                                                       │
│  agentdb CLI ─────→ surreal sql                       │
│  claude / gemini / codex ──→ agentdb CLI              │
│                                                       │
└───────────────────────────────────────────────────────┘
        │
        │ Docker Volume: agentdb-data → /home/dev/.agentdb
```

### 稼働形態

- 既存 playground コンテナに同居（単一コンテナ設計思想を維持）
- `surreal start` をバックグラウンドプロセスとして起動
- `127.0.0.1:8000` にバインド（コンテナ外からはアクセス不可）
- SurrealKV でファイルベース永続化

## 4. データモデル

### 4.1 DB: logs（TTL 14日 — 生データ）

```surql
DEFINE TABLE event SCHEMALESS;
DEFINE FIELD agent      ON event TYPE string;
DEFINE FIELD type       ON event TYPE string;
DEFINE FIELD data       ON event FLEXIBLE TYPE object;
DEFINE FIELD tags       ON event TYPE option<array<string>>;
DEFINE FIELD created_at ON event TYPE datetime DEFAULT time::now();

DEFINE INDEX idx_event_agent ON event FIELDS agent;
DEFINE INDEX idx_event_type  ON event FIELDS type;
DEFINE INDEX idx_event_time  ON event FIELDS created_at;
```

**共通フィールド:**
- `agent` — 記録者の識別子（claude, gemini, codex, 任意のエージェント名）
- `type` — イベント種別（conversation, tool_exec, qa_review, error, note, ...）
- `data` — 任意の構造化データ（SCHEMALESS）
- `tags` — 検索用タグ（任意）
- `created_at` — 自動タイムスタンプ

**type の例:**
| type | data の想定内容 |
|------|----------------|
| conversation | `{session_id, messages: [{role, content}], context}` |
| tool_exec | `{command, args, result, exit_code, duration_ms}` |
| qa_review | `{reviewer, target_agent, review_type, findings: [...]}` |
| error | `{error_type, message, stack_trace, resolution}` |
| note | `{content}` — 一時的なメモ |

### 4.2 DB: knowledge（永続 — 集合知）

```surql
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

-- エージェント間の知見の関係（グラフ）
DEFINE TABLE relates_to SCHEMALESS;
DEFINE FIELD relation   ON relates_to TYPE string;
DEFINE FIELD created_at ON relates_to TYPE datetime DEFAULT time::now();
```

**kind の例:**
| kind | 用途 |
|------|------|
| insight | 発見・知見 |
| decision | 意思決定とその根拠 |
| pattern | 繰り返し観測されるパターン |
| reference | 外部リソースへのポインタ |
| lesson | 失敗から学んだ教訓 |

**relates_to の relation 例:**
| relation | 意味 |
|----------|------|
| builds_on | 知見Aを発展させて知見Bが生まれた |
| contradicts | 知見Aと知見Bは矛盾する |
| supports | 知見Aが意思決定Bの根拠になった |
| derives_from | logsの生データから知見が抽出された |

### 4.3 設計原則

- **SCHEMALESS + 最小共通フィールド** — `agent`, `type/kind`, `tags`, `created_at` が共通契約。`data` は自由構造
- **グラフ関係は単一テーブル** — `relates_to` の `relation` フィールドで種別を表現
- **後から構造化可能** — 頻出パターンが見えたら `DEFINE FIELD` を追加

## 5. agentdb CLI

`surreal sql` のシェルラッパー。全エージェントが共通で利用。

```bash
# === logs DB ===
# イベント記録
agentdb log <type> '<data_json>'
agentdb log conversation '{"messages":[...],"context":"auth実装"}'
agentdb log tool_exec '{"cmd":"npm test","result":"pass"}'

# イベント検索
agentdb search <keyword> [--type <type>] [--agent <agent>] [--since <duration>]
agentdb search "認証" --agent gemini --since 7d

# === knowledge DB ===
# 知見の記録
agentdb save <kind> "<title>" "<body>" [--domain <domain>] [--tags tag1,tag2]
agentdb save insight "SurrealDBはTTL非対応" "cronで代替実装が必要" --domain database

# 知見の検索
agentdb find <keyword> [--kind <kind>] [--agent <agent>] [--domain <domain>]
agentdb find "認証" --kind decision

# === 共通 ===
# 生SurrealQL実行
agentdb query "<surql>" [--db logs|knowledge]

# TTLクリーンアップ（cron実行用）
agentdb cleanup
```

## 6. TTL 実装

SurrealDB にネイティブTTL機能がないため、cron + SurrealQL で実装。

```bash
# 日次 cron (毎日 03:00)
0 3 * * * /home/dev/scripts/agentdb-cleanup.sh
```

```surql
-- 14日超のイベントを削除
DELETE FROM event WHERE created_at < time::now() - 14d;
```

## 7. インフラ変更

### Dockerfile 追加内容

```dockerfile
# SurrealDB
RUN curl -sSf https://install.surrealdb.com | sh

# agentdb スクリプト群
COPY scripts/start-surreal.sh scripts/agentdb scripts/agentdb-cleanup.sh /home/dev/scripts/
COPY scripts/init-schema.surql /home/dev/scripts/
RUN chmod +x /home/dev/scripts/start-surreal.sh /home/dev/scripts/agentdb /home/dev/scripts/agentdb-cleanup.sh
```

### compose.yaml 追加

```yaml
volumes:
  agentdb-data:    # 追加
```

```yaml
services:
  playground:
    volumes:
      - agentdb-data:/home/dev/.agentdb    # 追加
```

## 8. ドキュメント

### docs/AGENTDB.md 構成

1. **目的** — マルチエージェント集合知基盤
2. **アーキテクチャ** — 2DB構成、データフロー
3. **データモデル** — logs/knowledge の構造、関係グラフ
4. **CLIリファレンス** — agentdb コマンド一覧と使用例
5. **エージェント向け活用ガイドライン**
   - いつ logs に記録するか
   - いつ knowledge に昇格させるか
   - 他エージェントの知見をどう参照するか
   - relates_to の使い方
6. **運用** — バックアップ、クリーンアップ、トラブルシューティング

### 既存ドキュメント変更

- `CLAUDE.md` — agentdb 活用方針セクション追加
- `AGENTS.md` — 共有DB利用ルール追加
- `GEMINI.md` — QAレビュー結果のDB記録ガイド追加

## 9. 新規・変更ファイル一覧

| ファイル | 操作 | 内容 |
|---------|------|------|
| `scripts/start-surreal.sh` | 新規 | SurrealDB起動、スキーマ初期化 |
| `scripts/init-schema.surql` | 新規 | DB/テーブル/インデックス定義 |
| `scripts/agentdb` | 新規 | CLIラッパー（bash） |
| `scripts/agentdb-cleanup.sh` | 新規 | TTLクリーンアップ |
| `docs/AGENTDB.md` | 新規 | 活用方針ドキュメント |
| `docs/plans/2026-03-18-agentdb-design.md` | 新規 | 本設計書 |
| `Dockerfile` | 変更 | SurrealDBインストール、スクリプト配置 |
| `compose.yaml` | 変更 | ボリューム追加 |
| `CLAUDE.md` | 変更 | agentdb活用方針追加 |
| `AGENTS.md` | 変更 | 共有DB利用ルール追加 |
| `GEMINI.md` | 変更 | DB記録ガイド追加 |
