# シナリオ: TDD（テスト駆動開発）フロー体験

テストが先に用意されており、実装がまだない状態から始めます。
Claude Code に TDD フローで実装させることを体験できます。

## 実行手順

```bash
cd ~/workspace
cp -r ~/examples/scenarios/tdd ./tdd-practice
cd tdd-practice

# 1. テストを確認（REDの状態）
uv sync
uv run pytest tests/ -v
# → 全テストが FAIL する

# 2. Claude Code に TDD で実装を依頼
claude
> "tests/test_calculator.py のテストがすべて通るように
>  src/calculator.py を実装して。TDDで進めて"

# 3. 実装後、Gemini にレビュー依頼
gemini -p "テストレビュー依頼:
実装: $(cat src/calculator.py)
テスト: $(cat tests/test_calculator.py)"
```

## ポイント

- Claude Code は test-driven-development skill により、
  テストを1つずつ通す形で進めるはず
- 最終的に全テストがGREENになることを確認
- Gemini のレビューでエッジケースの漏れがないか検証
