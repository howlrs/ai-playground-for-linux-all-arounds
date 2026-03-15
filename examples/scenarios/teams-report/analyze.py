"""Analyze Teams messages and generate a summary report."""

import argparse
import json
from collections import Counter
from datetime import datetime
from pathlib import Path


def load_messages(path: str) -> list[dict]:
    with open(path) as f:
        return json.load(f)


def analyze_messages(messages: list[dict]) -> dict:
    """Extract key insights from messages."""
    participants = Counter()
    dates = Counter()
    topics = []

    for msg in messages:
        user = msg["from"]["user"]["displayName"]
        participants[user] += 1

        dt = datetime.fromisoformat(msg["createdDateTime"].replace("Z", "+00:00"))
        dates[dt.strftime("%Y-%m-%d")] += 1

        content = msg["body"]["content"]
        # Simple keyword extraction
        for keyword in ["リリース", "バグ", "修正", "テスト", "セキュリティ", "パフォーマンス", "レビュー"]:
            if keyword in content:
                topics.append(keyword)

    return {
        "total_messages": len(messages),
        "participants": dict(participants.most_common()),
        "messages_per_day": dict(sorted(dates.items())),
        "key_topics": dict(Counter(topics).most_common()),
        "date_range": {
            "from": min(dates.keys()),
            "to": max(dates.keys()),
        },
    }


def generate_report(analysis: dict) -> str:
    """Generate markdown report from analysis."""
    lines = [
        "# Teams チャンネル分析レポート",
        "",
        f"期間: {analysis['date_range']['from']} 〜 {analysis['date_range']['to']}",
        f"総メッセージ数: {analysis['total_messages']}",
        "",
        "## 参加者別メッセージ数",
        "",
    ]
    for name, count in analysis["participants"].items():
        lines.append(f"- {name}: {count}件")

    lines.extend(["", "## 日別メッセージ数", ""])
    for date, count in analysis["messages_per_day"].items():
        lines.append(f"- {date}: {count}件")

    lines.extend(["", "## 主要トピック", ""])
    for topic, count in analysis["key_topics"].items():
        lines.append(f"- {topic}: {count}回言及")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Analyze Teams messages")
    parser.add_argument("--input", default=None, help="Path to messages JSON")
    parser.add_argument("--mock", action="store_true", help="Use mock data")
    parser.add_argument("--output", default="report.md", help="Output report path")
    args = parser.parse_args()

    if args.mock:
        input_path = str(Path(__file__).parent / "mock_messages.json")
    elif args.input:
        input_path = args.input
    else:
        parser.error("Either --input or --mock is required")

    messages = load_messages(input_path)
    analysis = analyze_messages(messages)
    report = generate_report(analysis)

    with open(args.output, "w") as f:
        f.write(report)

    print(report)
    print(f"\nReport saved to {args.output}")


if __name__ == "__main__":
    main()
