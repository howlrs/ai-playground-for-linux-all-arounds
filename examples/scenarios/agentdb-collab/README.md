# AgentDB マルチエージェント連携シナリオ

## 概要

複数のAIエージェントが AgentDB（SurrealDB）を通じて知見を共有し、
集合知を構築するワークフローを体験するシナリオ。

## 前提条件

```bash
# AgentDB が起動していること
agentdb status
# → SurrealDB: running と表示されればOK

# 起動していない場合
bash ~/scripts/start-surreal.sh
```

## シナリオ: Go API のバグ修正を集合知で解決

### ストーリー

1. Claude Code が go-api テンプレートのバグを調査
2. 調査過程と発見を AgentDB に記録
3. Gemini CLI にレビュー依頼し、結果を AgentDB に記録
4. 蓄積された知見を検索・参照しながら修正を完了

### Step 1: 準備

```bash
cp -r ~/examples/projects/go-api ~/workspace/go-api-practice
cd ~/workspace/go-api-practice

# エージェント名を設定
export AGENTDB_AGENT=claude
```

### Step 2: バグ調査と記録

```bash
# ビルドを試みる
go build -o server . 2>&1

# エラーを AgentDB に記録
agentdb log error '{"error_type":"build","message":"undefined: fmt in fmt.Sprintf","file":"main.go","line":53}'

# 調査メモを記録
agentdb log note '{"content":"main.go line 53 で fmt.Sprintf を使用しているが import \"fmt\" がない"}'
```

### Step 3: Gemini CLI にレビュー依頼 → 結果を記録

```bash
# Gemini CLI にレビュー依頼
gemini -p "コードレビュー依頼:
$(cat main.go)"

# レビュー結果を AgentDB に記録（Geminiの視点として）
export AGENTDB_AGENT=gemini
agentdb log qa_review '{"target_agent":"claude","review_type":"code","findings":[{"severity":"critical","description":"missing fmt import","suggestion":"add import fmt"}]}'

# 重要な知見を knowledge に昇格
agentdb save insight "Go: 未使用importはコンパイルエラーだが不足importは見落としやすい" \
  "fmt.Sprintf等を使う場合、importの存在確認を最初に行うべき" \
  --domain go --tags "go,import,compile-error"
```

### Step 4: 修正と知見の蓄積

```bash
export AGENTDB_AGENT=claude

# 修正を実施（Claude Code で）
claude "main.go の fmt import を追加して修正してください"

# 修正結果を記録
agentdb log tool_exec '{"cmd":"go build -o server .","exit_code":0,"duration_ms":1200}'

# 意思決定を記録
agentdb save decision "Go APIのimportバグを手動修正" \
  "goimportsではなく手動修正を選択。理由: 学習目的のため意図的にプロセスを踏む" \
  --domain go --tags "go,bugfix"
```

### Step 5: 蓄積された知見を確認

```bash
# 全体の活動を確認
agentdb status

# Go 関連の知見を検索
agentdb find "go" --domain go

# Gemini の指摘を確認
agentdb search "" --agent gemini --since 1d

# エラーの履歴を確認
agentdb search "" --type error --since 1d
```

## 学べること

- `agentdb log` で作業過程を記録する習慣
- `agentdb save` で重要な知見を永続化する判断
- エージェント間（Claude ↔ Gemini）の知見共有フロー
- `agentdb search` / `agentdb find` で過去の知見を活用する方法
- `AGENTDB_AGENT` の切り替えによるエージェント帰属の管理

## 発展

- `agentdb relate` でバグ → 修正 → 知見の関係をグラフ化する
- 別のシナリオ（tdd, teams-report）でも同様に AgentDB を活用し、横断的な知見を蓄積する
- 新しい専門エージェントを追加し、独自の視点からの知見を記録する
