# AI Playground for Linux - All Arounds

Docker上に構築するAIエージェント統合開発環境。
Claude Code（主）+ Gemini CLI（QA）+ Codex（補助）が連携して動作し、フルスタック開発に必要な全ツールを搭載。

## エージェント連携

```
ユーザー ──→ Claude Code (設計・実装・統括)
                  │
                  ├──→ Gemini CLI (QA: レビュー・検証)
                  │
                  └──→ Codex (補助: 単純タスク並列処理)
```

Claude Codeがメインエージェントとして設計・実装を行い、節目でGemini CLIにQAレビューを依頼。
Codexは単純タスクの並列処理に利用する。詳細は [AGENTS.md](AGENTS.md) を参照。

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

## 活用事例

### 事例1: Next.jsアプリケーションの新規開発

```
ユーザー: 「ブログ管理画面をNext.js + Prismaで作って」

Claude Code:
  1. brainstorming skill で要件整理・技術選定
  2. ユーザーと対話して画面構成・DB設計を確定
  3. Gemini CLI に設計レビュー依頼 → フィードバック反映
  4. writing-plans で実装計画作成
  5. npx create-next-app@latest → uv init (Python API部分)
  6. TDDで実装（テスト → 実装 → リファクタ）
  7. Codex にUI型定義・APIスキーマ生成を委任（並列処理）
  8. 実装完了 → Gemini CLI にフルコードレビュー
  9. レビュー指摘を修正 → gh pr create
```

### 事例2: Rustによるパフォーマンス改善

```
ユーザー: 「このPython処理が遅いので、コア部分をRustに置き換えたい」

Claude Code:
  1. 現状のPythonコードをプロファイリング
  2. ボトルネック特定 → Gemini CLI に分析結果を検証依頼
  3. cargo new で Rust プロジェクト作成（PyO3利用）
  4. TDDで Rust 実装 → Python バインディング作成
  5. uv add でPythonプロジェクトに統合
  6. ベンチマーク実行 → 改善結果をGemini CLIに評価依頼
  7. verification-before-completion で実際の速度改善を証明
```

### 事例3: 複数クラウド環境のインフラ調査

```
ユーザー: 「GCPとAWSの現状リソースを棚卸しして」

Claude Code:
  1. gcloud projects list → プロジェクト一覧取得
  2. aws ec2 describe-instances → インスタンス一覧取得
  3. 各リソースの利用状況を集計（読み取り操作のみ → 自由に実行）
  4. レポート作成 → Gemini CLI にレポートの網羅性を検証依頼
  5. ユーザーに報告
  ※ リソースの作成・削除は行わない（ポリシー準拠）
```

### 事例4: Teamsメッセージの分析とレポート

```
ユーザー: 「先週のTeamsの #dev チャンネルの議論をまとめて」

Claude Code:
  1. m365 teams team list → チーム一覧取得
  2. m365 teams channel list → チャンネル特定
  3. m365 teams message list → メッセージ取得（読み取り → 自由に実行）
  4. メッセージを分析・要約
  5. Gemini CLI に要約の正確性を検証依頼
  6. レポートをMarkdownで作成
  ※ メッセージ送信はユーザー確認が必要（ポリシー準拠）
```

### 事例5: Go + Rustのマイクロサービス開発

```
ユーザー: 「Go でAPIゲートウェイ、Rustで認証サービスを作って」

Claude Code:
  1. brainstorming でサービス間通信方式を設計（gRPC / REST）
  2. Gemini CLI に設計レビュー（セキュリティ観点重視）
  3. go mod init → cargo new で2プロジェクト作成
  4. 認証サービス（Rust）をTDDで実装
  5. APIゲートウェイ（Go）をTDDで実装
  6. Codex に OpenAPI定義・Protobuf定義の生成を委任
  7. 結合テスト → Gemini CLI にセキュリティレビュー
  8. gh pr create（各サービス個別PR）
```

### 事例6: Google Workspace横断のデータ収集

```
ユーザー: 「複数Googleアカウントのカレンダーを統合表示して」

Claude Code:
  1. gws auth setup → アカウントA認証
  2. gws calendar events list → 予定取得
  3. 別アカウントで再認証 or サービスアカウント切替
  4. gws calendar events list → 予定取得
  5. Python (uv run) で予定を統合・整形
  6. 見やすいレポートを生成
  ※ カレンダーの変更操作はユーザー確認が必要
```

## ドキュメント

| ファイル | 内容 |
|---------|------|
| [CLAUDE.md](CLAUDE.md) | Claude Code行動指針 - ワークフロー、QA連携、CLIポリシー |
| [AGENTS.md](AGENTS.md) | エージェント連携定義 - 役割分担、依頼パターン、フロー図 |
| [GEMINI.md](GEMINI.md) | Gemini CLIガイド - QAレビュー観点、回答フォーマット |
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
