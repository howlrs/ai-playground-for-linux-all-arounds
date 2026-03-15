"""Calculator tests - implementation does not exist yet (RED state)."""

import pytest
from src.calculator import Calculator


class TestBasicOperations:
    def test_add(self):
        calc = Calculator()
        assert calc.add(2, 3) == 5

    def test_add_negative(self):
        calc = Calculator()
        assert calc.add(-1, -1) == -2

    def test_subtract(self):
        calc = Calculator()
        assert calc.subtract(10, 4) == 6

    def test_multiply(self):
        calc = Calculator()
        assert calc.multiply(3, 7) == 21

    def test_divide(self):
        calc = Calculator()
        assert calc.divide(10, 2) == 5.0

    def test_divide_by_zero(self):
        calc = Calculator()
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            calc.divide(10, 0)


class TestAdvancedOperations:
    def test_power(self):
        calc = Calculator()
        assert calc.power(2, 10) == 1024

    def test_power_zero(self):
        calc = Calculator()
        assert calc.power(5, 0) == 1

    def test_sqrt(self):
        calc = Calculator()
        assert calc.sqrt(16) == 4.0

    def test_sqrt_negative(self):
        calc = Calculator()
        with pytest.raises(ValueError, match="Cannot take square root of negative"):
            calc.sqrt(-1)


class TestHistory:
    def test_history_starts_empty(self):
        calc = Calculator()
        assert calc.history() == []

    def test_history_records_operations(self):
        calc = Calculator()
        calc.add(1, 2)
        calc.multiply(3, 4)
        h = calc.history()
        assert len(h) == 2
        assert h[0] == {"op": "add", "args": (1, 2), "result": 3}
        assert h[1] == {"op": "multiply", "args": (3, 4), "result": 12}

    def test_clear_history(self):
        calc = Calculator()
        calc.add(1, 1)
        calc.clear_history()
        assert calc.history() == []
