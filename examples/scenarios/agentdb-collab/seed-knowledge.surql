-- AgentDB Seed Data
-- シナリオ開始前に投入するサンプル知見データ
-- Usage: surreal sql --endpoint http://127.0.0.1:8000 --username root --password root < seed-knowledge.surql

USE NS agents DB knowledge;

-- 過去のエージェントの知見（シナリオのコンテキストとして）
CREATE entry SET
  agent = 'claude',
  kind = 'pattern',
  domain = 'go',
  title = 'Go: コンパイルエラーの調査手順',
  body = '1. go build でエラーメッセージ確認 → 2. 該当行のimport/型を確認 → 3. go vet で静的解析',
  tags = ['go', 'debugging', 'workflow'],
  created_at = time::now(),
  updated_at = time::now();

CREATE entry SET
  agent = 'gemini',
  kind = 'insight',
  domain = 'code-review',
  title = 'レビューでimport漏れは頻出する',
  body = 'コードレビュー時、新規追加された関数呼び出しに対応するimport文の確認を最初に行うと効率的',
  tags = ['review', 'import', 'best-practice'],
  created_at = time::now(),
  updated_at = time::now();

CREATE entry SET
  agent = 'claude',
  kind = 'lesson',
  domain = 'testing',
  title = 'テスト前にビルド確認を挟む',
  body = 'go test の前に go build を実行し、コンパイルエラーを先に解消する。テストエラーとコンパイルエラーの混同を防ぐ',
  tags = ['go', 'testing', 'workflow'],
  created_at = time::now(),
  updated_at = time::now();
