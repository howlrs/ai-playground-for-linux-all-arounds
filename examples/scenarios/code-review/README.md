# シナリオ: Gemini QA コードレビュー

意図的にバグと設計上の問題を含んだコードを用意しています。
Gemini CLI の QA レビューがどのように機能するかを体験できます。

## 実行手順

```bash
cd ~/workspace
cp -r ~/examples/scenarios/code-review ./review-practice
cd review-practice

# 1. まずコードを確認
cat server.ts

# 2. Gemini CLI にレビュー依頼
gemini -p "コードレビュー依頼:
$(cat server.ts)"

# 3. Gemini のレビュー結果を確認
#    Critical / Important / Suggestion に分類された指摘が返る

# 4. Claude Code に修正を依頼
claude
> "Gemini のレビュー結果を踏まえてこのコードを修正して"
```

## 含まれるバグ・問題

このファイルには以下の問題が意図的に含まれています（ネタバレ注意）:

<details>
<summary>答えを見る</summary>

1. **Critical**: SQLインジェクション脆弱性（パラメータ未エスケープ）
2. **Critical**: パスワードを平文でレスポンスに含めている
3. **Important**: エラー時にスタックトレースをクライアントに返している
4. **Important**: レート制限なし（DoSリスク）
5. **Suggestion**: マジックナンバー使用
6. **Suggestion**: エラーハンドリングの一貫性なし

</details>
