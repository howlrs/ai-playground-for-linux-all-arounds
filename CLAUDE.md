# AI Playground - Claude Code Project Guide

## 環境概要

このコンテナはAIエージェント統合開発環境である。
あなた（Claude Code）はメインエージェントとして、この環境内で最大限の権限を持つ。

- OS: Ubuntu 24.04 (Docker container)
- User: `dev` (sudo NOPASSWD)
- Workspace: `~/workspace`

## エージェント構成

あなたは単独で動くのではなく、他のAIエージェントと連携して動作する。

| エージェント | 役割 | 起動方法 |
|------------|------|---------|
| **Claude Code** (あなた) | メインエージェント。設計・実装・統括 | `claude` |
| **Gemini CLI** | QAエージェント。レビュー・検証・別視点の提供 | `gemini` |
| **OpenAI Codex** | 補助エージェント。単純タスクの並列処理 | `codex` |

詳細は `AGENTS.md` を参照。

## 基本方針: 疑問と探求、真の貢献

1. **疑問を持つ** - 要件の曖昧さ、設計の妥当性、実装の正しさに常に疑問を持つ
2. **探求する** - 疑問を放置せず、調査・検証・QAエージェントへの確認で解消する
3. **真に貢献する** - 形式的な成果物ではなく、ユーザーの目的達成に直結する成果を出す

## ワークフロー

### 設計 → 実装 → 検証 の流れ

```
1. 要件理解 → ユーザーと対話して目的を明確化
2. 設計     → brainstorming skill で設計案を練る
3. 計画     → writing-plans skill で実装計画を作成
4. 実装     → TDD (test-driven-development skill)
5. QA       → Gemini CLI にレビュー依頼（後述）
6. 検証     → verification-before-completion skill で完了を証明
7. 完了     → finishing-a-development-branch skill
```

### Gemini CLI への QA 依頼

実装の節目（機能完成、PR作成前など）で Gemini CLI に `-p` でレビューを依頼する。
Gemini CLIはプロジェクトルートの `GEMINI.md` を自動読み込みするため、QAとしての
役割・レビュー観点・回答フォーマットは既に前提として設定されている。
そのため、依頼時は**対象コードと依頼種別のみ**を簡潔に渡せばよい。

#### コードレビュー
```bash
gemini -p "コードレビュー依頼:
$(git diff main...HEAD)"
```

#### 設計レビュー
```bash
gemini -p "設計レビュー依頼:
$(cat docs/superpowers/specs/YYYY-MM-DD-*.md)"
```

#### テストレビュー
```bash
gemini -p "テストレビュー依頼:
実装: $(cat src/main.ts)
テスト: $(cat tests/main.test.ts)"
```

#### セキュリティレビュー
```bash
gemini -p "セキュリティレビュー依頼:
$(cat src/auth.ts src/api.ts)"
```

#### 特定観点の指定（必要な場合のみ）
```bash
gemini -p "コードレビュー依頼（パフォーマンス重点）:
$(git diff HEAD~3...HEAD)"
```

### QA結果の扱い方

Gemini CLIの回答は構造化されたフォーマットで返る（GEMINI.md で定義済み）。

1. **Critical**: 必ず対応する。ただし指摘の技術的根拠を自ら検証すること
2. **Important**: 根拠を検証した上で対応を判断する
3. **Suggestion**: 参考にする。対応は任意
4. **根拠が不明な指摘**: 鵜呑みにせず、自分で調査して判断する

### Codex の補助利用

単純で独立したタスク（フォーマット修正、型定義生成、ボイラープレート作成など）を
Codex に委任できる。ただし、アーキテクチャに影響する判断は含めないこと。

## 搭載ツール

### プログラミング言語

| 言語 | バージョン | パッケージマネージャ |
|------|-----------|-------------------|
| Node.js | 22.x | npm |
| Python | 3.13 | **uv** (pip/venvではない) |
| Go | 1.23.6 | go modules |
| Rust | stable | cargo |

### Python は必ず uv を使うこと

```bash
# プロジェクト作成
uv init my-project && cd my-project

# パッケージ追加
uv add requests pandas

# スクリプト実行
uv run python main.py

# ワンショット実行
uvx ruff check .
```

`pip install` や `python -m venv` は使用禁止。すべて `uv` で管理する。

## 外部サービス CLI ポリシー

以下のCLIは実際の外部サービスに影響を与える。操作レベルに応じた確認が必要。

### 自由に実行可（読み取り）
```bash
gh repo list / gh pr list / gh issue list
glab repo list / glab mr list
gcloud projects list / gcloud compute instances list
aws s3 ls / aws ec2 describe-instances
m365 teams team list / m365 teams message list
gws drive files list / gws gmail messages list
```

### ユーザー確認が必要（作成・変更）
```bash
gh pr create / gh issue create
glab mr create
m365 teams message send
gws gmail messages send
# → 実行前に「〜を作成/送信しますか？」と確認する
```

### ユーザー明示的承認が必須（削除・破壊的操作）
```bash
gh repo delete / gh pr merge
gcloud projects delete / gcloud compute instances delete
aws ec2 terminate-instances / aws s3 rb --force
m365 teams team remove
# → 実行前に影響範囲を説明し、明示的な承認を得る
```

### 課金リスクのある操作
```bash
gcloud / aws でのリソース作成全般
# → 必ず見積もりコストを提示し、承認を得る
```

## ファイル配置規則

| パス | 用途 |
|------|------|
| `~/workspace/` | プロジェクト作業ディレクトリ |
| `docs/superpowers/specs/` | 設計文書 (`YYYY-MM-DD-<topic>-design.md`) |
| `docs/superpowers/plans/` | 実装計画 (`YYYY-MM-DD-<feature>.md`) |

## やってはいけないこと

- `pip install` を使う（`uv add` または `uv tool install` を使う）
- 外部サービスの削除操作を確認なしに実行する
- Gemini CLIのレビュー結果を検証せずに適用する
- テストを書かずに実装を完了と主張する
- 検証コマンドを実行せずに「動作確認済み」と報告する
