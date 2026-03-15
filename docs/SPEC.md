# 仕様書 - AI Playground for Linux

## 1. 概要

本プロジェクトは、Docker上に構築されるAIエージェント統合開発環境である。
Claude Codeをメインエージェント、Gemini CLIをQAサブエージェントとして運用し、
Codexを補助的に利用可能とする。コンテナ内ではAIエージェントにローカル操作の
最大限の権限を付与し、外部サービス操作のみ制限付きで扱う。

## 2. システム構成

### 2.1 コンテナ基盤

| 項目 | 仕様 |
|------|------|
| ベースイメージ | Ubuntu 24.04 LTS |
| アーキテクチャ | x86_64 (amd64) |
| コンテナ構成 | 単一コンテナ（全ツール同居） |
| オーケストレーション | Docker Compose |
| メモリ制限 | 8GB (上限) / 2GB (予約) |
| ネットワーク | bridge（制限なし） |

### 2.2 ユーザー・権限

| 項目 | 仕様 |
|------|------|
| コンテナ内ユーザー | `dev` (UID:1000, GID:1000) |
| sudo | NOPASSWD（全コマンド許可） |
| ホスト連携 | `.gitconfig`, `.ssh` を読み取り専用マウント |

## 3. 搭載ツール一覧

### 3.1 AIエージェント

| ツール | パッケージ | 用途 |
|--------|-----------|------|
| Claude Code | `@anthropic-ai/claude-code` | メインエージェント |
| Gemini CLI | `@google/gemini-cli` | QAサブエージェント |
| OpenAI Codex | `@openai/codex` | 補助エージェント |

### 3.2 プログラミング言語・ランタイム

| 言語 | バージョン | パッケージマネージャ |
|------|-----------|-------------------|
| Node.js | 22.x | npm |
| Python | 3.13 (uv管理) | uv |
| Go | 1.23.6 | go modules |
| Rust | stable | cargo |

### 3.3 プラットフォームCLI

| ツール | 用途 |
|--------|------|
| git | バージョン管理 |
| gh | GitHub操作 |
| glab | GitLab操作 |
| gcloud | Google Cloud操作 |
| aws | AWS操作 |

### 3.4 ワークスペースツール

| ツール | パッケージ | 用途 |
|--------|-----------|------|
| Google Workspace CLI | `@googleworkspace/cli` | Drive, Gmail, Calendar等 |
| CLI for Microsoft 365 | `@pnp/cli-microsoft365` | Teams, SharePoint等 |
| notebooklm-py | PyPI (uv tool) | NotebookLM操作 |
| msgraph-sdk | PyPI (uv tool) | Microsoft Graph API |
| azure-identity | PyPI (uv tool) | Azure認証 |

### 3.5 ユーティリティ

| ツール | 用途 |
|--------|------|
| vim | テキストエディタ |
| tmux | ターミナルマルチプレクサ |
| jq | JSON処理 |
| ripgrep (rg) | 高速テキスト検索 |
| fd-find (fd) | 高速ファイル検索 |
| curl / wget | HTTP通信 |
| build-essential | C/C++コンパイラ一式 |

## 4. 永続化仕様

以下のデータはDockerボリュームにより、コンテナ再構築後も保持される。

| ボリューム名 | マウント先 | 内容 |
|-------------|-----------|------|
| `claude-config` | `/home/dev/.claude` | Claude Code設定・認証 |
| `gemini-config` | `/home/dev/.gemini` | Gemini CLI設定 |
| `codex-config` | `/home/dev/.codex` | Codex設定 |
| `uv-cache` | `/home/dev/.cache/uv` | uvパッケージキャッシュ |
| `m365-config` | `/home/dev/.cli-m365` | M365 CLI認証情報 |
| `./workspace` | `/home/dev/workspace` | 作業ディレクトリ（バインドマウント） |

## 5. 認証仕様

### 5.1 環境変数による認証

`.env`ファイルで注入する。`.env.example`をテンプレートとして提供。

| 変数名 | 対象ツール |
|--------|-----------|
| `ANTHROPIC_API_KEY` | Claude Code |
| `GEMINI_API_KEY` | Gemini CLI |
| `OPENAI_API_KEY` | Codex |
| `GH_TOKEN` / `GITHUB_TOKEN` | GitHub CLI |
| `GITLAB_TOKEN` | GitLab CLI |
| `M365_APP_ID` | M365 CLI |
| `M365_TENANT_ID` | M365 CLI |
| `M365_APP_SECRET` | M365 CLI |

### 5.2 ファイルマウントによる認証

| ホストパス | コンテナパス | 対象 |
|-----------|------------|------|
| `~/.gitconfig` | `/home/dev/.gitconfig` (ro) | git |
| `~/.ssh` | `/home/dev/.ssh` (ro) | SSH/git |
| `~/.config/gcloud` | `/home/dev/.config/gcloud` (ro) | gcloud (任意) |
| `~/.aws` | `/home/dev/.aws` (ro) | aws (任意) |

## 6. 外部サービス操作ポリシー

`docs/CAUTION.md` に詳細を記載。

| レベル | 操作種別 | ポリシー |
|--------|---------|---------|
| 自由 | 読み取り (list, get, describe) | 確認不要 |
| 推奨 | 作成 (create) | ユーザー確認推奨 |
| 必須 | 変更 (update, modify) | ユーザー確認必須 |
| 厳格 | 削除 (delete, destroy) | ユーザー明示的承認必須 |

## 7. ファイル構成

```
.
├── Dockerfile              # コンテナイメージ定義
├── compose.yaml            # Docker Compose設定
├── .env.example            # 環境変数テンプレート
├── .gitignore              # Git除外設定
├── scripts/
│   ├── setup-all.sh        # 一括セットアップ
│   ├── setup-claude.sh     # Claude Code認証
│   ├── setup-gemini.sh     # Gemini CLI認証
│   ├── setup-codex.sh      # Codex認証
│   ├── setup-gws.sh        # Google Workspace CLI認証
│   ├── setup-teams.sh      # Microsoft 365 CLI認証
│   └── setup-cloud.sh      # gcloud/aws/gh/glab認証
└── docs/
    ├── SPEC.md             # 本仕様書
    ├── DESCRIPTION.md      # 説明書
    ├── USAGE.md            # 利用書
    └── CAUTION.md          # 外部サービス注意事項
```
