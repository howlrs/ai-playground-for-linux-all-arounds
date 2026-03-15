"""Tests for data analysis functions."""

from main import load_sample_data, analyze


def test_load_sample_data_shape():
    df = load_sample_data()
    assert len(df) == 30
    assert "revenue" in df.columns


def test_analyze_returns_all_keys():
    df = load_sample_data()
    result = analyze(df)
    assert "total_revenue" in result
    assert "avg_daily_revenue" in result
    assert "top_product" in result
    assert "total_units" in result


def test_revenue_is_positive():
    df = load_sample_data()
    result = analyze(df)
    assert result["total_revenue"] > 0
    assert result["avg_daily_revenue"] > 0
