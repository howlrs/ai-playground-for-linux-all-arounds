# AI Playground for Linux - All Arounds

Docker上に構築するAIエージェント統合開発環境。
Claude Code（主）+ Gemini CLI（QA）+ Codex（補助）が自由に動作し、フルスタック開発に必要な全ツールを搭載。

## 搭載ツール

| カテゴリ | ツール |
|---------|--------|
| AIエージェント | Claude Code, Gemini CLI, OpenAI Codex |
| 言語 | Node.js 22, Python 3.13 (uv), Go 1.23, Rust stable |
| プラットフォーム | git, gh (GitHub), glab (GitLab) |
| クラウド | gcloud, aws-cli v2 |
| ワークスペース | Google Workspace CLI, CLI for Microsoft 365, notebooklm-py, msgraph-sdk |
| ユーティリティ | vim, tmux, jq, ripgrep, fd-find |

## クイックスタート

```bash
git clone git@github.com:howlrs/ai-playground-for-linux-all-arounds.git
cd ai-playground-for-linux-all-arounds

cp .env.example .env
# .env に ANTHROPIC_API_KEY, GEMINI_API_KEY 等を記入

docker compose build
docker compose up -d
docker compose exec playground bash

# コンテナ内で認証状態を確認
~/scripts/setup-all.sh

# Claude Code を起動
claude
```

## ドキュメント

| ファイル | 内容 |
|---------|------|
| [docs/SPEC.md](docs/SPEC.md) | 仕様書 - システム構成、ツール一覧、認証・永続化仕様 |
| [docs/DESCRIPTION.md](docs/DESCRIPTION.md) | 説明書 - 設計思想、アーキテクチャ、技術選定理由 |
| [docs/USAGE.md](docs/USAGE.md) | 利用書 - 全ツールの使い方、トラブルシューティング |
| [docs/CAUTION.md](docs/CAUTION.md) | 外部サービスCLI操作の注意事項 |

## 外部サービスCLIポリシー

コンテナ内のAIエージェントにはローカル操作の最大権限を付与しています。
**外部サービスCLI（gh, glab, gcloud, aws, m365）のみ操作レベルに応じた制限あり。**

| 操作 | ポリシー |
|------|---------|
| 読み取り (list, get) | 自由 |
| 作成 (create) | ユーザー確認推奨 |
| 変更 (update) | ユーザー確認必須 |
| 削除 (delete) | 明示的承認必須 |

詳細は [docs/CAUTION.md](docs/CAUTION.md) を参照。

## ライセンス

MIT
