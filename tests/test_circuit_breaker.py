"""
Unit tests for Circuit Breaker pattern implementation
"""

import unittest
import time
import threading
from unittest.mock import MagicMock, patch

import sys
import os

sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), "../components/ai-agent")),
)

from circuit_breaker import CircuitBreaker, CircuitBreakerOpenError, CircuitState


class TestCircuitBreaker(unittest.TestCase):
    def setUp(self):
        """Set up test fixtures"""
        self.cb = CircuitBreaker(
            name="test",
            fail_max=3,
            reset_timeout=1.0,  # Short timeout for testing
            exclude_exceptions=(ValueError,),
        )

    def test_initial_state(self):
        """Test circuit starts in CLOSED state"""
        self.assertEqual(self.cb.state, CircuitState.CLOSED)
        self.assertEqual(self.cb.failure_count, 0)
        self.assertEqual(self.cb.success_count, 0)

    def test_successful_execution(self):
        """Test successful function execution"""
        mock_func = MagicMock(return_value="success")

        result = self.cb.execute(mock_func, "arg1", kwarg="value")

        self.assertEqual(result, "success")
        self.assertEqual(self.cb.state, CircuitState.CLOSED)
        mock_func.assert_called_once_with("arg1", kwarg="value")

    def test_failure_counting(self):
        """Test failure counting"""
        mock_func = MagicMock(side_effect=Exception("test error"))

        # First failure
        with self.assertRaises(Exception):
            self.cb.execute(mock_func)
        self.assertEqual(self.cb.failure_count, 1)
        self.assertEqual(self.cb.state, CircuitState.CLOSED)

        # Second failure
        with self.assertRaises(Exception):
            self.cb.execute(mock_func)
        self.assertEqual(self.cb.failure_count, 2)
        self.assertEqual(self.cb.state, CircuitState.CLOSED)

    def test_circuit_opens_after_failures(self):
        """Test circuit opens after max failures"""
        mock_func = MagicMock(side_effect=Exception("test error"))

        # Trigger 3 failures (fail_max)
        for _ in range(3):
            with self.assertRaises(Exception):
                self.cb.execute(mock_func)

        # Circuit should now be OPEN
        self.assertEqual(self.cb.state, CircuitState.OPEN)
        self.assertEqual(self.cb.failure_count, 3)

    def test_circuit_blocks_when_open(self):
        """Test requests fail fast when circuit is OPEN"""
        # Open the circuit
        self.cb.state = CircuitState.OPEN
        self.cb.failure_count = 3
        self.cb.last_failure_time = time.time()

        mock_func = MagicMock()

        # Should raise CircuitBreakerOpenError immediately
        with self.assertRaises(CircuitBreakerOpenError):
            self.cb.execute(mock_func)

        # Function should not have been called
        mock_func.assert_not_called()

    def test_circuit_half_open_after_timeout(self):
        """Test circuit transitions to HALF_OPEN after timeout"""
        # Open the circuit
        self.cb.state = CircuitState.OPEN
        self.cb.failure_count = 3
        self.cb.last_failure_time = time.time() - 2.0  # 2 seconds ago (past timeout)

        mock_func = MagicMock(return_value="success")

        # Execute - should transition to HALF_OPEN and allow execution
        result = self.cb.execute(mock_func)

        self.assertEqual(result, "success")
        self.assertEqual(self.cb.state, CircuitState.CLOSED)

    def test_half_open_test_failure(self):
        """Test HALF_OPEN state re-opens on failure"""
        # Set to HALF_OPEN
        self.cb.state = CircuitState.HALF_OPEN
        self.cb.success_count = 0

        mock_func = MagicMock(side_effect=Exception("test error"))

        # Failure should re-open circuit
        with self.assertRaises(Exception):
            self.cb.execute(mock_func)

        self.assertEqual(self.cb.state, CircuitState.OPEN)

    def test_excluded_exceptions(self):
        """Test excluded exceptions don't count as failures"""
        mock_func = MagicMock(side_effect=ValueError("excluded"))

        # ValueError is excluded, shouldn't count as failure
        with self.assertRaises(ValueError):
            self.cb.execute(mock_func)

        self.assertEqual(self.cb.failure_count, 0)
        self.assertEqual(self.cb.state, CircuitState.CLOSED)

    def test_fallback_function(self):
        """Test fallback function is called when circuit is open"""
        fallback = MagicMock(return_value="fallback_result")
        cb = CircuitBreaker(
            name="test_fallback",
            fail_max=1,
            reset_timeout=60.0,
            fallback_function=fallback,
        )

        # Open the circuit
        cb.state = CircuitState.OPEN
        cb.failure_count = 1
        cb.last_failure_time = time.time()

        mock_func = MagicMock()

        # Should use fallback
        result = cb.execute(mock_func)

        self.assertEqual(result, "fallback_result")
        fallback.assert_called_once()
        mock_func.assert_not_called()

    def test_thread_safety(self):
        """Test circuit breaker is thread-safe"""
        cb = CircuitBreaker(name="thread_test", fail_max=10, reset_timeout=60.0)
        results = []
        lock = threading.Lock()

        def worker():
            mock_func = MagicMock(return_value="success")
            try:
                result = cb.execute(mock_func)
                with lock:
                    results.append(result)
            except Exception as e:
                with lock:
                    results.append(str(e))

        # Start multiple threads
        threads = [threading.Thread(target=worker) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # All should succeed
        self.assertEqual(len(results), 10)
        self.assertTrue(all(r == "success" for r in results))
        self.assertEqual(cb.state, CircuitState.CLOSED)

    def test_get_state(self):
        """Test get_state returns correct dictionary"""
        self.cb.failure_count = 2
        self.cb.success_count = 5

        state = self.cb.get_state()

        self.assertEqual(state["name"], "test")
        self.assertEqual(state["state"], "CLOSED")
        self.assertEqual(state["failure_count"], 2)
        self.assertEqual(state["success_count"], 5)


class TestCircuitBreakersConfig(unittest.TestCase):
    """Test pre-configured circuit breakers"""

    def test_circuit_breakers_exist(self):
        """Test all pre-configured circuit breakers exist"""
        from circuit_breaker import CircuitBreakers

        self.assertIsNotNone(CircuitBreakers.ollama)
        self.assertIsNotNone(CircuitBreakers.redis)
        self.assertIsNotNone(CircuitBreakers.k8s_api)
        self.assertIsNotNone(CircuitBreakers.git)

    def test_get_all_states(self):
        """Test get_all_states returns all circuit states"""
        from circuit_breaker import CircuitBreakers

        states = CircuitBreakers.get_all_states()

        self.assertIn("ollama", states)
        self.assertIn("redis", states)
        self.assertIn("k8s_api", states)
        self.assertIn("git", states)

        for name, state in states.items():
            self.assertIn("state", state)
            self.assertIn("failure_count", state)


if __name__ == "__main__":
    unittest.main()
