# シナリオ: Teams メッセージ分析レポート

Microsoft Teams のメッセージを取得・分析し、レポートを生成するワークフロー。
m365 CLI が未認証の場合はモックデータで動作を確認できます。

## 実行手順

### モックデータで体験

```bash
cd ~/workspace
cp -r ~/examples/scenarios/teams-report ./teams-practice
cd teams-practice

# 1. モックデータでレポート生成
uv sync
uv run python analyze.py --mock

# 2. Claude Code に分析を依頼
claude
> "mock_messages.json のTeamsメッセージを分析して、
>  今週の議論のサマリーレポートを作成して"
```

### 実際のTeamsデータで実行

```bash
# 1. m365 認証
m365 login

# 2. チーム・チャンネル確認
m365 teams team list
m365 teams channel list --teamId <team-id>

# 3. メッセージ取得
m365 teams message list --teamId <team-id> --channelId <channel-id> --output json > messages.json

# 4. 分析
uv run python analyze.py --input messages.json
```
