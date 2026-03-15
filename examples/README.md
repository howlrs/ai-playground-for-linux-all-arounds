# Examples

AI Playground環境の活用例。コンテナ起動後、`~/examples/` からコピーして利用します。

## プロジェクトテンプレート (`projects/`)

ゼロからプロジェクトを始めるためのテンプレート。

| テンプレート | 言語 | 内容 |
|------------|------|------|
| [nextjs-app](projects/nextjs-app/) | TypeScript | Next.js 15 + TypeScript の最小構成 |
| [go-api](projects/go-api/) | Go | 標準ライブラリのみのREST API（意図的バグ含む） |
| [rust-cli](projects/rust-cli/) | Rust | clap + serde のCLIタスク管理ツール |
| [python-data](projects/python-data/) | Python | pandas + matplotlib のデータ分析（uv管理） |

### 使い方

```bash
# コンテナ内で
cp -r ~/examples/projects/<template> ~/workspace/<your-project>
cd ~/workspace/<your-project>

# Claude Code で開発開始
claude
```

## ワークフローシナリオ (`scenarios/`)

エージェント連携ワークフローを体験するためのシナリオ。

| シナリオ | 体験内容 |
|---------|---------|
| [code-review](scenarios/code-review/) | 意図的にバグを含むコードをGemini CLIにQAレビューさせる |
| [tdd](scenarios/tdd/) | テストが先、実装が空の状態からClaude CodeにTDDで実装させる |
| [teams-report](scenarios/teams-report/) | Teamsモックデータからメッセージ分析レポートを生成する |

### 使い方

```bash
# コンテナ内で
cp -r ~/examples/scenarios/<scenario> ~/workspace/<your-practice>
cd ~/workspace/<your-practice>
cat README.md  # 手順を確認
```
