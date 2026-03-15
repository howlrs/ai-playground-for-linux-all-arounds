# Python データ分析テンプレート

pandas + matplotlib による最小構成のデータ分析プロジェクト。uv管理。

## セットアップ

```bash
cp -r ~/examples/projects/python-data ~/workspace/my-analysis
cd ~/workspace/my-analysis
uv sync
uv run python main.py
```

## テスト

```bash
uv run pytest tests/
```

## AIエージェントへの依頼例

```
claude > "matplotlibで月次売上グラフを生成して"
claude > "外部APIからデータを取得してDataFrameに変換して"
claude > "Jupyter Notebookで分析レポートを作成して"
```
