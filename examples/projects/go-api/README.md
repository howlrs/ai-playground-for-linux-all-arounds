# Go REST API テンプレート

Go 1.23 標準ライブラリのみで構成したシンプルなREST API。

## セットアップ

```bash
cp -r ~/examples/projects/go-api ~/workspace/my-api
cd ~/workspace/my-api
go run .
```

## エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | /tasks | タスク一覧 |
| POST | /tasks | タスク作成 |

## AIエージェントへの依頼例

```
claude > "PUT /tasks/{id} と DELETE /tasks/{id} を追加して"
claude > "SQLiteでデータを永続化して"
claude > "ミドルウェアでリクエストログを追加して"
```

## 注意

このテンプレートには意図的に `fmt` パッケージの import 漏れがあります。
AIエージェントに修正させる練習として利用できます。
