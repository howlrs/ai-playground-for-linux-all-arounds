"""Simple data analysis example using pandas."""

import pandas as pd


def load_sample_data() -> pd.DataFrame:
    """Create sample sales data."""
    data = {
        "date": pd.date_range("2026-01-01", periods=30, freq="D"),
        "product": ["Widget A", "Widget B", "Widget C"] * 10,
        "quantity": [12, 8, 15, 20, 5, 10, 18, 3, 22, 7] * 3,
        "price": [100, 250, 50] * 10,
    }
    df = pd.DataFrame(data)
    df["revenue"] = df["quantity"] * df["price"]
    return df


def analyze(df: pd.DataFrame) -> dict:
    """Analyze sales data and return summary."""
    return {
        "total_revenue": int(df["revenue"].sum()),
        "avg_daily_revenue": int(df.groupby("date")["revenue"].sum().mean()),
        "top_product": df.groupby("product")["revenue"].sum().idxmax(),
        "total_units": int(df["quantity"].sum()),
    }


def main():
    df = load_sample_data()
    summary = analyze(df)

    print("=== Sales Analysis ===")
    for key, value in summary.items():
        print(f"  {key}: {value}")

    # Save to CSV
    df.to_csv("sales_data.csv", index=False)
    print("\nData saved to sales_data.csv")


if __name__ == "__main__":
    main()
