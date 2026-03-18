# 利用書 - AI Playground for Linux

## 前提条件

- Docker Engine 24.0 以上
- Docker Compose v2
- ホストマシンに `~/.gitconfig` と `~/.ssh` が存在すること

## クイックスタート

### 1. リポジトリのクローン

```bash
git clone git@github.com:howlrs/ai-playground-for-linux-all-arounds.git
cd ai-playground-for-linux-all-arounds
```

### 2. 環境変数の設定

```bash
cp .env.example .env
```

`.env` を編集し、最低限以下を設定：

```
ANTHROPIC_API_KEY=sk-ant-...    # Claude Code用（必須）
GEMINI_API_KEY=AI...            # Gemini CLI用（必須）
OPENAI_API_KEY=sk-...           # Codex用（任意）
```

### 3. ビルドと起動

```bash
# 初回ビルド（10〜20分程度）
docker compose build

# コンテナ起動
docker compose up -d

# コンテナに入る
docker compose exec playground bash
```

### 4. 初期セットアップ確認

```bash
~/scripts/setup-all.sh
```

全ツールのインストール状況と認証状態が表示される。

## AIエージェントの使い方

### Claude Code（メインエージェント）

```bash
# 起動
claude

# 特定ディレクトリで作業
cd ~/workspace/my-project && claude
```

### Gemini CLI（QAエージェント）

```bash
# 起動
gemini

# Claude Codeからサブエージェントとして呼び出す場合は
# Claude Codeの設定でGemini CLIをツールとして登録
```

### OpenAI Codex（補助）

```bash
codex
```

## AgentDB（マルチエージェント共有DB）

AgentDB は SurrealDB ベースの共有データベース。エージェント間で知見を共有・蓄積する。
`setup-all.sh` 実行時に自動起動される。

### 基本操作

```bash
# ステータス確認
agentdb status

# イベント記録（logs DB, TTL 14日）
agentdb log conversation '{"context":"認証実装","summary":"OAuth2設計を議論"}'
agentdb log error '{"message":"build failed","resolution":"missing import"}'

# 知見の永続化（knowledge DB）
agentdb save insight "Go importバグは頻出" "新規関数追加時にimport確認を最初に行う" --domain go --tags "go,import"
agentdb save decision "OAuth2+PKCEを採用" "コンプライアンス要件を満たすため" --domain auth

# 検索
agentdb search "認証" --since 7d         # logs検索
agentdb find "OAuth" --kind decision      # knowledge検索

# 知見間の関係を記録
agentdb relate entry:abc builds_on entry:xyz

# 生SurrealQL実行
agentdb query "SELECT * FROM event ORDER BY created_at DESC LIMIT 5;" --db logs
```

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AGENTDB_AGENT` | `claude`（compose.yaml設定） | 記録者のエージェント名 |
| `AGENTDB_BIND` | `127.0.0.1:8000` | SurrealDB アドレス |

### 手動起動・停止

```bash
# 手動起動（通常はsetup-all.shで自動起動）
bash ~/scripts/start-surreal.sh

# TTLクリーンアップ（通常はcronで日次自動実行）
agentdb cleanup

# ログ確認
cat ~/.agentdb/surreal.log
```

詳細: `docs/AGENTDB.md`

## プログラミング言語の使い方

### Python (uv)

```bash
# 新規プロジェクト作成
uv init my-project
cd my-project

# パッケージ追加
uv add requests pandas

# スクリプト実行
uv run python main.py

# 一時的にパッケージを使う（インストール不要）
uvx ruff check .
uvx black .

# グローバルツールインストール
uv tool install ruff
```

### Node.js / Next.js

```bash
# Next.jsプロジェクト作成
npx create-next-app@latest my-app

# パッケージインストール
npm install

# 開発サーバー起動
npm run dev
```

### Go

```bash
# モジュール初期化
go mod init my-module

# ビルドと実行
go build -o app .
go run .
```

### Rust

```bash
# プロジェクト作成
cargo new my-project
cd my-project

# ビルドと実行
cargo run

# リリースビルド
cargo build --release
```

## ワークスペースツールの使い方

### Google Workspace CLI (gws)

```bash
# 認証セットアップ
gws auth setup

# Drive操作
gws drive files list
gws drive files get --fileId <id>

# Gmail操作
gws gmail messages list --userId me
gws gmail messages get --userId me --id <id>

# Calendar操作
gws calendar events list --calendarId primary
```

複数Googleアカウントの切り替え：
```bash
# 別アカウントで認証
gws auth setup  # 新しいアカウントでログイン

# サービスアカウント切り替え
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/other-account.json
```

### Microsoft Teams (m365 CLI)

```bash
# 初回認証（デバイスコードフロー）
m365 login

# 非対話認証（Docker/CI向け）
m365 login --authType secret \
  --appId $M365_APP_ID \
  --tenant $M365_TENANT_ID \
  --secret $M365_APP_SECRET

# チーム一覧
m365 teams team list

# チャンネル一覧
m365 teams channel list --teamId <team-id>

# メッセージ取得
m365 teams message list --teamId <team-id> --channelId <channel-id>

# チャットメッセージ取得
m365 teams chat message list --chatId <chat-id>
```

### NotebookLM

```bash
# 初回認証（ブラウザが開く）
notebooklm login

# ノートブック一覧
notebooklm list
```

### Microsoft Graph API (Python)

> **注意:** `msgraph-sdk` と `azure-identity` はグローバルインストールではなく、
> プロジェクト依存として追加する: `uv add msgraph-sdk azure-identity`

```python
# uv run python で実行
from azure.identity import DeviceCodeCredential
from msgraph import GraphServiceClient

credential = DeviceCodeCredential(
    client_id="YOUR_APP_ID",
    tenant_id="YOUR_TENANT_ID"
)
client = GraphServiceClient(credential)

# Teams一覧取得
teams = await client.me.joined_teams.get()
```

## プラットフォームCLI

### GitHub (gh)

```bash
# 認証
gh auth login
# または
export GH_TOKEN=ghp_...

# よく使う操作
gh repo list
gh pr list
gh issue list
```

### GitLab (glab)

```bash
# 認証
glab auth login
# または
export GITLAB_TOKEN=glpat-...

# よく使う操作
glab repo list
glab mr list
```

### Google Cloud (gcloud)

```bash
# 認証（ヘッドレス環境向け）
gcloud auth login --no-launch-browser

# プロジェクト設定
gcloud config set project <project-id>
```

### AWS

```bash
# 認証設定
aws configure
# または
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# 動作確認
aws sts get-caller-identity
```

## コンテナ管理

```bash
# コンテナ停止（データは保持）
docker compose stop

# コンテナ再起動
docker compose start

# コンテナ削除（ボリュームは保持）
docker compose down

# 完全リセット（ボリュームも削除）
docker compose down -v

# イメージ再ビルド
docker compose build --no-cache

# ログ確認
docker compose logs -f playground
```

## トラブルシューティング

### ビルドが失敗する

```bash
# キャッシュなしで再ビルド
docker compose build --no-cache
```

### APIキーが認識されない

```bash
# .envファイルの確認
cat .env | grep -v '^#' | grep -v '^$'

# コンテナ内で環境変数を確認
echo $ANTHROPIC_API_KEY
echo $GEMINI_API_KEY
```

### SSH接続ができない

```bash
# ホスト側のSSHキーのパーミッション確認
ls -la ~/.ssh/
# id_rsa は 600 であること

# コンテナ内から確認
ssh -T git@github.com
```

### uvでPythonパッケージがインストールできない

```bash
# キャッシュクリア
uv cache clean

# Python再インストール
uv python install 3.13 --force
```

### m365ログインでブラウザが開かない

Docker内ではブラウザが使えないため、デバイスコードフローを使う：
```bash
m365 login
# 表示されるコードをホストマシンのブラウザで入力
```
