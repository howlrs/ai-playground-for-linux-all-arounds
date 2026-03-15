# External Service CLI - 注意事項

## 基本方針

このコンテナ内のAIエージェント（Claude Code, Gemini CLI）には、ローカルファイル操作において最大限の権限を与えています。
**ただし、外部サービスに影響を与えるCLI操作については、以下の注意が必要です。**

## 注意が必要なコマンド

### gh (GitHub CLI)
| 操作 | リスク |
|------|--------|
| `gh repo delete` | リポジトリ完全削除 |
| `gh pr merge` | マージ実行 |
| `gh issue close` | Issue変更 |
| `gh release create/delete` | リリース操作 |
| `gh api -X DELETE` | API経由の削除操作 |

### glab (GitLab CLI)
| 操作 | リスク |
|------|--------|
| `glab mr merge` | マージリクエスト実行 |
| `glab project delete` | プロジェクト削除 |
| `glab ci delete` | CI/CDパイプライン削除 |

### gcloud (Google Cloud)
| 操作 | リスク |
|------|--------|
| `gcloud compute instances delete` | VMインスタンス削除 |
| `gcloud projects delete` | プロジェクト削除 |
| `gcloud sql instances delete` | DBインスタンス削除 |
| リソース作成全般 | **課金が発生** |

### aws (AWS CLI)
| 操作 | リスク |
|------|--------|
| `aws ec2 terminate-instances` | EC2インスタンス終了 |
| `aws s3 rb --force` | S3バケット強制削除 |
| `aws rds delete-db-instance` | RDSインスタンス削除 |
| リソース作成全般 | **課金が発生** |

## AIエージェントへの指針

1. **読み取り操作（list, describe, get）** → 自由に実行可
2. **作成操作（create）** → ユーザー確認を推奨
3. **変更操作（update, modify）** → ユーザー確認を必須
4. **削除操作（delete, destroy, terminate）** → ユーザー明示的承認が必須

## CLAUDE.md への設定例

```markdown
# External CLI Policy
- gh, glab: read operations are free, write/delete require user confirmation
- gcloud, aws: ALL operations require user confirmation (billing risk)
- gws: read operations are free, send/modify require user confirmation
```
