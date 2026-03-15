# AI Playground for Linux - Design Document

## Purpose

Claude Codeをメインエージェント、Gemini CLIをQAサブエージェントとして、
Docker上に完全な開発環境を構築する。コンテナ内ではAIエージェントに最大限の
ローカル権限を与え、外部サービスCLIのみ注意して扱う。

## Architecture

- **Single container**: Claude Code + Gemini CLI同居、全dev toolchain搭載
- **Base**: Ubuntu 24.04
- **User**: non-root (`dev`) with `sudo NOPASSWD`

## Components

| Category | Tools |
|----------|-------|
| AI Agents | Claude Code, Gemini CLI |
| VCS/Platform | git, gh, glab |
| Cloud CLI | gcloud, aws-cli v2 |
| Languages | Rust/Cargo, Go 1.23, Node.js 22, Python 3 |
| Workspace | Google Workspace CLI (gws), notebooklm-py |
| Utilities | curl, jq, vim, tmux, ripgrep, fd-find |

## Permission Model

- Container internal: full sudo, unrestricted file/network access
- External CLIs (gh, glab, gcloud, aws): documented caution in `docs/CAUTION.md`
- API keys: injected via `.env` file, never committed

## File Structure

```
├── Dockerfile           # Full environment build
├── compose.yaml         # Volume mounts, env injection
├── .env.example         # API key template
├── .gitignore
├── scripts/
│   ├── setup-claude.sh  # Claude Code auth check
│   ├── setup-gemini.sh  # Gemini CLI auth check
│   ├── setup-gws.sh     # Google Workspace CLI auth
│   ├── setup-cloud.sh   # gcloud/aws/gh/glab auth
│   └── setup-all.sh     # Unified setup runner
└── docs/
    ├── CAUTION.md        # External service policy
    └── plans/
```

## Usage

```bash
cp .env.example .env     # Fill API keys
docker compose up -d     # Start container
docker compose exec playground bash
~/scripts/setup-all.sh   # Verify auth
claude                   # Start working
```
