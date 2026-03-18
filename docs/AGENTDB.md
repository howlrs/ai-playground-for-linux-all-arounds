# AgentDB — マルチエージェント集合知基盤

## 1. 目的

AgentDB は、複数のAIエージェント（Claude Code, Gemini CLI, OpenAI Codex、および将来の専門エージェント群）が会話・実行ログ・知見・意思決定を **共有情報として永続化** し、各々の視座と専門性から集合知を構築するための基盤である。

### 解決する課題

- エージェントの会話やアウトプットが揮発的で、セッション間で失われる
- あるエージェントの知見を別のエージェントが参照できない
- 試行錯誤の履歴が残らず、同じ失敗を繰り返す
- 多数の専門エージェントがアサインされた際の情報共有手段がない

AgentDB を通じて、エージェントは「個」としてではなく「集団」として知識を蓄積し、活用できる。

## 2. アーキテクチャ

SurrealDB v3.x を採用。単一コンテナ内でバックグラウンドプロセスとして稼働する。

```
playground コンテナ
┌─────────────────────────────────────────────────────────┐
│                                                           │
│  surreal start surrealkv:///home/dev/.agentdb/data        │
│  --bind 127.0.0.1:8000 --user root --pass root            │
│  (バックグラウンドプロセス)                                  │
│                                                           │
│  Namespace: agents                                        │
│  ┌──────────────────────────┐  ┌───────────────────────┐  │
│  │ DB: logs                 │  │ DB: knowledge         │  │
│  │ TTL: 14日（cron削除）     │  │ 永続                   │  │
│  │                          │  │                       │  │
│  │ Table: event             │  │ Table: entry          │  │
│  │ (SCHEMALESS)             │  │ (SCHEMALESS)          │  │
│  │                          │  │                       │  │
│  │ 会話要約, ツール実行,     │  │ 知見, 意思決定,        │  │
│  │ QAレビュー, エラー,       │  │ パターン, 参照,        │  │
│  │ メモ                     │  │ 教訓                   │  │
│  └──────────────────────────┘  │                       │  │
│                                │ Table: relates_to     │  │
│                                │ (グラフリレーション)     │  │
│                                │ builds_on, contradicts│  │
│                                │ supports, derives_from│  │
│                                └───────────────────────┘  │
│                                                           │
│  エージェント ──→ agentdb CLI ──→ surreal sql             │
│  (claude / gemini / codex / 専門エージェント)              │
│                                                           │
└───────────────────────────────────────────────────────────┘
        │
        │ Docker Volume: agentdb-data → /home/dev/.agentdb
```

### データフローの概要

```
エージェントの作業中
  │
  ├── 即時記録 ──→ agentdb log (logs DB, TTL 14日)
  │                   生データ: 会話, ツール実行, エラー, メモ
  │
  ├── 重要な発見 ──→ agentdb save (knowledge DB, 永続)
  │                   集合知: 知見, 意思決定, パターン, 教訓
  │
  └── 関連付け ──→ agentdb relate (グラフリレーション)
                     知見間の関係: 発展, 矛盾, 支持, 導出
```

## 3. データモデル

### 3.1 DB: logs — 生データ（TTL 14日）

テーブル `event`（SCHEMALESS）にイベントを記録する。14日経過したレコードはcronジョブで自動削除される。

#### フィールド定義

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `agent` | `string` | 記録者の識別子（claude, gemini, codex, 任意のエージェント名） |
| `type` | `string` | イベント種別 |
| `data` | `object` (FLEXIBLE) | 任意の構造化データ（SCHEMALESS） |
| `tags` | `option<array<string>>` | 検索用タグ（任意） |
| `created_at` | `datetime` | 自動タイムスタンプ（DEFAULT time::now()） |

#### type の例

| type | data の想定内容 |
|------|----------------|
| `conversation` | `{session_id, messages: [{role, content}], context}` |
| `tool_exec` | `{command, args, result, exit_code, duration_ms}` |
| `qa_review` | `{reviewer, target_agent, review_type, findings: [...]}` |
| `error` | `{error_type, message, stack_trace, resolution}` |
| `note` | `{content}` — 一時的なメモ |

#### インデックス

```surql
DEFINE INDEX idx_event_agent ON event FIELDS agent;
DEFINE INDEX idx_event_type  ON event FIELDS type;
DEFINE INDEX idx_event_time  ON event FIELDS created_at;
```

### 3.2 DB: knowledge — 集合知（永続）

#### テーブル: entry

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `agent` | `string` | 記録者の識別子 |
| `kind` | `string` | 知見の種別 |
| `domain` | `option<string>` | 技術ドメイン分類 |
| `title` | `string` | タイトル |
| `body` | `string` | 本文 |
| `data` | `object` (FLEXIBLE) | 追加の構造化データ（任意） |
| `tags` | `option<array<string>>` | 検索用タグ（任意） |
| `created_at` | `datetime` | 作成日時（DEFAULT time::now()） |
| `updated_at` | `datetime` | 更新日時（DEFAULT time::now()） |

#### kind の例

| kind | 用途 |
|------|------|
| `insight` | 発見・知見 |
| `decision` | 意思決定とその根拠 |
| `pattern` | 繰り返し観測されるパターン |
| `reference` | 外部リソースへのポインタ |
| `lesson` | 失敗から学んだ教訓 |

#### インデックス

```surql
DEFINE INDEX idx_entry_agent  ON entry FIELDS agent;
DEFINE INDEX idx_entry_kind   ON entry FIELDS kind;
DEFINE INDEX idx_entry_domain ON entry FIELDS domain;
```

#### テーブル: relates_to（グラフエッジ）

知見間の関係をグラフ構造で表現する。SurrealDB のネイティブグラフ機能（`RELATE ... -> relates_to -> ...`）を利用。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `relation` | `string` | 関係の種別 |
| `created_at` | `datetime` | 作成日時（DEFAULT time::now()） |

#### relation の種別

| relation | 意味 | 使い方 |
|----------|------|--------|
| `builds_on` | 知見Aを発展させて知見Bが生まれた | 既存知見の深化・拡張 |
| `contradicts` | 知見Aと知見Bは矛盾する | 異なる結論の明示（対立は価値がある） |
| `supports` | 知見Aが意思決定Bの根拠になった | 判断の裏付けを記録 |
| `derives_from` | logsの生データから知見が抽出された | ログからの昇格を追跡 |

### 3.3 設計原則

- **SCHEMALESS + 最小共通フィールド** — `agent`, `type`/`kind`, `tags`, `created_at` が共通契約。`data` は自由構造
- **グラフ関係は単一テーブル** — `relates_to` の `relation` フィールドで種別を表現
- **後から構造化可能** — 頻出パターンが見えたら `DEFINE FIELD` を追加

## 4. CLI リファレンス

### 4.1 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AGENTDB_AGENT` | `unknown` | 呼び出し元エージェント名。**必ず設定すること** |
| `AGENTDB_BIND` | `127.0.0.1:8000` | SurrealDB アドレス |
| `AGENTDB_USER` | `root` | SurrealDB ユーザー名 |
| `AGENTDB_PASS` | `root` | SurrealDB パスワード |

各エージェントは起動時に `AGENTDB_AGENT` を設定する:

```bash
export AGENTDB_AGENT=claude   # Claude Code
export AGENTDB_AGENT=gemini   # Gemini CLI（Claude Code が代理記録）
export AGENTDB_AGENT=codex    # OpenAI Codex
export AGENTDB_AGENT=<name>   # カスタムエージェント
```

### 4.2 logs DB コマンド

#### `agentdb log` — イベント記録

```bash
agentdb log <type> '<data_json>'
```

**使用例:**

```bash
# 会話の要約を記録
agentdb log conversation '{"session_id":"sess-001","context":"認証実装","summary":"OAuth2フローの設計を議論。PKCE採用を決定"}'

# ツール実行の結果を記録
agentdb log tool_exec '{"cmd":"npm test","exit_code":0,"duration_ms":3200,"result":"42 tests passed"}'

# QAレビュー結果を記録
agentdb log qa_review '{"target_agent":"claude","review_type":"code","findings":[{"severity":"important","description":"N+1クエリの可能性"}]}'

# エラーと解決策を記録
agentdb log error '{"error_type":"build","message":"TypeScript compilation failed","resolution":"missing type import for AuthConfig"}'

# 一時的なメモ
agentdb log note '{"content":"この設計パターンは後で再検討が必要。GraphQLスキーマとの整合性を確認すること"}'
```

#### `agentdb search` — イベント検索

```bash
agentdb search <keyword> [--type <type>] [--agent <agent>] [--since <duration>] [--limit <n>]
```

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--type` | イベント種別でフィルタ | `--type error` |
| `--agent` | エージェント名でフィルタ | `--agent gemini` |
| `--since` | 時間範囲を指定 | `--since 7d`, `--since 24h` |
| `--limit` | 最大件数（デフォルト: 20） | `--limit 5` |

**使用例:**

```bash
# キーワードで検索
agentdb search "認証"

# Gemini のレビュー結果を直近7日間で検索
agentdb search "レビュー" --type qa_review --agent gemini --since 7d

# 直近24時間のエラーを5件取得
agentdb search "error" --type error --since 24h --limit 5

# 特定エージェントの最近の活動を確認
agentdb search "" --agent codex --since 3d
```

### 4.3 knowledge DB コマンド

#### `agentdb save` — 知見の記録

```bash
agentdb save <kind> "<title>" "<body>" [--domain <domain>] [--tags <t1,t2,...>]
```

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--domain` | 技術ドメイン分類 | `--domain auth` |
| `--tags` | カンマ区切りのタグ | `--tags "surrealdb,ttl"` |

**使用例:**

```bash
# 知見を保存
agentdb save insight "SurrealDBはネイティブTTL非対応" \
  "cronジョブで14日超のレコードを日次削除する設計とした。SurrealDB v4以降でネイティブTTL対応の可能性あり" \
  --domain database --tags "surrealdb,ttl,design-decision"

# 意思決定を記録
agentdb save decision "認証方式にOAuth2+PKCEを採用" \
  "セッショントークンのコンプライアンス要件を満たすため、OAuth2 + PKCE を選択。JWTセッションは要件不適合" \
  --domain auth --tags "oauth2,compliance,security"

# パターンを記録
agentdb save pattern "Geminiは型安全性の指摘が鋭い" \
  "コードレビューでGeminiが指摘する型関連の問題は高確率で実際のバグに繋がる。型関連の指摘は優先的に対応すべき" \
  --tags "gemini,qa,observation"

# 教訓を記録
agentdb save lesson "モックテストとDBの乖離に注意" \
  "モックが通ってもprodマイグレーションが失敗した事例あり。重要なDB操作は統合テストを優先すべき" \
  --domain testing --tags "testing,database,incident"

# 外部参照を記録
agentdb save reference "SurrealDB グラフクエリ公式ドキュメント" \
  "https://surrealdb.com/docs/surrealql/statements/relate - RELATE文とグラフトラバーサルの詳細" \
  --domain database --tags "surrealdb,documentation"
```

#### `agentdb find` — 知見の検索

```bash
agentdb find <keyword> [--kind <kind>] [--agent <agent>] [--domain <domain>] [--limit <n>]
```

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--kind` | 知見の種別でフィルタ | `--kind decision` |
| `--agent` | エージェント名でフィルタ | `--agent gemini` |
| `--domain` | ドメインでフィルタ | `--domain auth` |
| `--limit` | 最大件数（デフォルト: 20） | `--limit 10` |

**使用例:**

```bash
# キーワードで検索
agentdb find "認証"

# 特定ドメインの意思決定履歴を確認
agentdb find "" --kind decision --domain auth

# Geminiが記録したセキュリティ関連の知見
agentdb find "セキュリティ" --agent gemini --domain security

# 全エージェントの教訓を取得
agentdb find "" --kind lesson --limit 50
```

#### `agentdb relate` — グラフリレーション作成

```bash
agentdb relate <from_id> <relation> <to_id>
```

レコードIDは `entry:<id>` 形式で指定する（`agentdb save` や `agentdb find` の結果に含まれる）。

**使用例:**

```bash
# 知見Aが知見Bの発展であることを記録
agentdb relate entry:abc123 builds_on entry:xyz789

# 知見Aが知見Bと矛盾することを記録
agentdb relate entry:new_finding contradicts entry:old_assumption

# 知見Aが意思決定Bの根拠であることを記録
agentdb relate entry:security_insight supports entry:oauth2_decision

# ログから抽出された知見であることを記録
agentdb relate entry:extracted_pattern derives_from entry:raw_observation
```

### 4.4 共通コマンド

#### `agentdb query` — 生SurrealQL実行

```bash
agentdb query "<surql>" [--db logs|knowledge]
```

デフォルトは `logs` DB に対して実行。`--db knowledge` で knowledge DB を指定。

**使用例:**

```bash
# logs DB: 直近のエラーを確認
agentdb query "SELECT * FROM event WHERE type = 'error' ORDER BY created_at DESC LIMIT 5;"

# knowledge DB: 特定ドメインの全エントリ
agentdb query "SELECT * FROM entry WHERE domain = 'auth';" --db knowledge

# knowledge DB: グラフトラバーサル — ある知見に関連する全エントリ
agentdb query "SELECT <-relates_to<-entry AS related_from, ->relates_to->entry AS related_to FROM entry:target_id;" --db knowledge

# knowledge DB: 特定の relation で繋がるエントリを辿る
agentdb query "SELECT ->relates_to[WHERE relation = 'supports']->entry FROM entry:insight_id;" --db knowledge

# logs DB: エージェント別のイベント数を集計
agentdb query "SELECT agent, count() AS total FROM event GROUP BY agent;"
```

#### `agentdb status` — ヘルスチェック

```bash
agentdb status
```

SurrealDB の稼働状態と各DBのレコード数を表示する。

**出力例:**

```
=== AgentDB Status ===
Endpoint: http://127.0.0.1:8000
Namespace: agents

--- Logs DB ---
[{ total: 142 }]

--- Knowledge DB ---
[{ total: 23 }]
```

#### `agentdb cleanup` — TTLクリーンアップ

```bash
agentdb cleanup
```

logs DB の14日超のイベントを手動で削除する。通常はcronジョブが日次で自動実行するため、手動実行は不要。

## 5. エージェント向け活用ガイドライン

### 5.1 いつ logs に記録するか

以下のタイミングでイベントを記録する:

| タイミング | type | 記録内容 |
|-----------|------|---------|
| セッション終了時 | `conversation` | 会話の要約、議論した内容、結論 |
| 重要なツール実行後 | `tool_exec` | テスト実行、ビルド、デプロイの結果 |
| QAレビュー受領時 | `qa_review` | Gemini CLI からのレビュー結果 |
| エラー発生・解決時 | `error` | エラー内容と解決方法 |
| 一時的なメモ | `note` | 後で参照したいが永続化するほどではない情報 |

**記録しなくてよいもの:**
- ルーティンのファイル読み書き
- 単純なコマンド実行（ls, cd など）
- 情報量の少い中間状態

### 5.2 いつ knowledge に昇格させるか

logs の情報が以下の条件を満たす場合、knowledge に昇格させる:

- **繰り返し参照される知見** — 複数回 logs から同じ情報を探した場合、それは永続化すべき
- **意思決定の記録** — なぜその選択をしたのか、将来の判断に影響する場合
- **パターンの発見** — 複数の事象から見出された法則性（例: 「Geminiの型指摘はバグ率が高い」）
- **教訓** — 失敗や成功から得られた、再利用可能な学び
- **他エージェントにとって有用** — 自分だけでなく、他のエージェントが参照する価値がある情報

**昇格の例:**

```bash
# logs で繰り返し「SurrealDB TTL」を検索していた → knowledge に昇格
agentdb save insight "SurrealDBはネイティブTTL非対応" \
  "cronジョブで代替実装が必要。DELETE FROM event WHERE created_at < time::now() - 14d;" \
  --domain database --tags "surrealdb,ttl"
```

### 5.3 他エージェントの知見をどう参照するか

**作業開始時の確認ルーティン:**

```bash
# 1. 担当ドメインの既存知見を確認
agentdb find "" --domain <担当ドメイン>

# 2. 関連テーマの意思決定履歴を確認
agentdb find "<テーマ>" --kind decision

# 3. 他エージェントの最近の活動を確認
agentdb search "" --agent <agent-name> --since 3d

# 4. 直近のエラーと教訓を確認
agentdb find "" --kind lesson --domain <担当ドメイン>
```

**なぜ確認するのか:**
- 他エージェントが既に同じ問題を調査・解決している可能性がある
- 意思決定の根拠を知ることで、矛盾する変更を避けられる
- 教訓を事前に知ることで、同じ失敗を繰り返さない

### 5.4 relates_to の使い方

知見は孤立させず、関係性を記録する。グラフ構造により、関連する知見のネットワークが形成される。

#### builds_on — 発展

既存の知見を深化・拡張した場合:

```bash
# 「OAuth2採用」の知見を発展させて「PKCE必須」の知見を追加
agentdb save insight "OAuth2ではPKCE必須" \
  "パブリッククライアントではPKCEなしのOAuth2は脆弱。RFC 7636準拠が必要" \
  --domain auth --tags "oauth2,pkce,security"
# → 返されたIDを使って
agentdb relate entry:pkce_insight builds_on entry:oauth2_decision
```

#### contradicts — 矛盾

異なる結論に達した場合。矛盾は集合知において価値がある:

```bash
# 以前の知見と矛盾する新しい発見
agentdb save insight "JWTセッションも要件を満たせる" \
  "新しいコンプライアンスガイドライン改定により、JWTでも条件付きで許可された" \
  --domain auth --tags "jwt,compliance"
agentdb relate entry:jwt_ok contradicts entry:jwt_ng
```

#### supports — 支持

知見が意思決定の根拠になる場合:

```bash
agentdb relate entry:security_audit_finding supports entry:oauth2_decision
```

#### derives_from — 導出

ログの生データから知見を抽出した場合:

```bash
# 複数のエラーログから共通パターンを抽出
agentdb save pattern "DBコネクションプールの枯渇パターン" \
  "同時接続数50超でタイムアウト発生。プールサイズの動的調整が必要" \
  --domain database --tags "connection-pool,performance"
agentdb relate entry:pool_pattern derives_from entry:error_analysis
```

## 6. 運用

### 6.1 バックアップ

knowledge DB は永続データであり、定期的なバックアップを推奨する:

```bash
# knowledge DB のエクスポート
surreal export \
  --conn http://127.0.0.1:8000 \
  --user root --pass root \
  --ns agents --db knowledge \
  knowledge-backup-$(date +%Y%m%d).surql

# logs DB のエクスポート（必要に応じて）
surreal export \
  --conn http://127.0.0.1:8000 \
  --user root --pass root \
  --ns agents --db logs \
  logs-backup-$(date +%Y%m%d).surql
```

リストア:

```bash
surreal import \
  --conn http://127.0.0.1:8000 \
  --user root --pass root \
  --ns agents --db knowledge \
  knowledge-backup-20260318.surql
```

### 6.2 TTL クリーンアップ

logs DB のイベントは14日で自動削除される。日次cronジョブとして設定:

```bash
# crontab 設定（毎日 03:00 に実行）
0 3 * * * /home/dev/scripts/agentdb-cleanup.sh
```

手動実行:

```bash
agentdb cleanup
```

実行される SurrealQL:

```surql
DELETE FROM event WHERE created_at < time::now() - 14d;
```

### 6.3 トラブルシューティング

#### SurrealDB が起動しない

```bash
# ステータス確認
agentdb status

# ログを確認
cat ~/.agentdb/surreal.log

# 手動で再起動
bash ~/scripts/start-surreal.sh
```

#### agentdb コマンドが見つからない

```bash
# PATH を確認
which agentdb

# 直接パスで実行
~/scripts/agentdb status

# PATH に追加
export PATH="$HOME/scripts:$PATH"
```

#### レコードが見つからない

```bash
# DB を間違えていないか確認（logs vs knowledge）
agentdb query "SELECT * FROM event LIMIT 5;" --db logs
agentdb query "SELECT * FROM entry LIMIT 5;" --db knowledge

# AGENTDB_AGENT が正しく設定されているか確認
echo $AGENTDB_AGENT
```

#### ディスク使用量の確認

```bash
du -sh ~/.agentdb/data
```

データが肥大化している場合は手動クリーンアップを実行:

```bash
# logs の古いデータを削除
agentdb cleanup

# knowledge の不要エントリを個別削除
agentdb query "DELETE entry:unwanted_id;" --db knowledge
```
