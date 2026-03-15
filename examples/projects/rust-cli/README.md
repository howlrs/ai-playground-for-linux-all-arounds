# Rust CLI テンプレート

clap + serde による最小構成のCLIタスク管理ツール。

## セットアップ

```bash
cp -r ~/examples/projects/rust-cli ~/workspace/my-cli
cd ~/workspace/my-cli
cargo run -- add "最初のタスク"
cargo run -- list
cargo run -- done 1
```

## AIエージェントへの依頼例

```
claude > "期限（due date）フィールドを追加して、期限順でソートして表示して"
claude > "SQLiteバックエンドに切り替えて"
claude > "cargo test でユニットテストを追加して"
```
