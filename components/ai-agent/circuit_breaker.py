"""
Circuit Breaker Pattern Implementation for AI4ALL-SRE
Provides resilience for external dependencies (Ollama, Redis, K8s API)
"""

import time
import functools
import threading
from enum import Enum
from typing import Callable, Any, Optional
from loguru import logger


class CircuitState(Enum):
    """Circuit breaker states"""

    CLOSED = "CLOSED"  # Normal operation
    OPEN = "OPEN"  # Circuit open, requests fail fast
    HALF_OPEN = "HALF_OPEN"  # Testing if service recovered


class CircuitBreaker:
    """
    Circuit breaker pattern implementation.

    - CLOSED: Normal operation. Failures are counted.
    - OPEN: After fail_max failures, circuit opens. Requests fail immediately.
    - HALF_OPEN: After reset_timeout, circuit allows one test request.
        - If success: circuit closes
        - If failure: circuit opens again
    """

    def __init__(
        self,
        name: str,
        fail_max: int = 5,
        reset_timeout: float = 60.0,
        exclude_exceptions: tuple = (),
        fallback_function: Optional[Callable] = None,
    ):
        self.name = name
        self.fail_max = fail_max
        self.reset_timeout = reset_timeout
        self.exclude_exceptions = exclude_exceptions
        self.fallback_function = fallback_function

        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.last_failure_time = 0
        self.success_count = 0

        self._lock = threading.RLock()

        logger.info(
            f"[+] Circuit breaker '{name}' initialized (fail_max={fail_max}, reset_timeout={reset_timeout}s)"
        )

    def _can_execute(self) -> bool:
        """Check if request can be executed"""
        with self._lock:
            if self.state == CircuitState.CLOSED:
                return True

            if self.state == CircuitState.OPEN:
                # Check if reset timeout has passed
                if time.time() - self.last_failure_time >= self.reset_timeout:
                    self.state = CircuitState.HALF_OPEN
                    logger.info(f"[CB:{self.name}] Circuit transitioning to HALF_OPEN")
                    return True
                return False

            if self.state == CircuitState.HALF_OPEN:
                # Only allow one request in HALF_OPEN state
                return self.success_count == 0

        return False

    def _on_success(self):
        """Handle successful request"""
        with self._lock:
            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.CLOSED
                logger.info(f"[CB:{self.name}] Circuit CLOSED (service recovered)")

            self.failure_count = 0
            self.success_count += 1

    def _on_failure(self, exception: Exception):
        """Handle failed request"""
        with self._lock:
            # Check if exception should be excluded
            if isinstance(exception, self.exclude_exceptions):
                return

            self.failure_count += 1
            self.success_count = 0
            self.last_failure_time = time.time()

            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.OPEN
                logger.warning(
                    f"[CB:{self.name}] Circuit re-OPENED (test request failed)"
                )

            elif self.failure_count >= self.fail_max:
                self.state = CircuitState.OPEN
                logger.error(
                    f"[CB:{self.name}] Circuit OPENED (failures: {self.failure_count})"
                )

    def execute(self, func: Callable, *args, **kwargs) -> Any:
        """Execute function with circuit breaker protection"""
        if not self._can_execute():
            if self.fallback_function:
                logger.warning(
                    f"[CB:{self.name}] Circuit {self.state.value}, using fallback"
                )
                return self.fallback_function(*args, **kwargs)
            raise CircuitBreakerOpenError(
                f"Circuit breaker '{self.name}' is {self.state.value}"
            )

        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except Exception as e:
            self._on_failure(e)
            raise

    def get_state(self) -> dict:
        """Get current circuit state"""
        with self._lock:
            return {
                "name": self.name,
                "state": self.state.value,
                "failure_count": self.failure_count,
                "success_count": self.success_count,
                "last_failure_time": self.last_failure_time,
            }


class CircuitBreakerOpenError(Exception):
    """Exception raised when circuit breaker is open"""

    pass


def circuit_breaker(
    name: str,
    fail_max: int = 5,
    reset_timeout: float = 60.0,
    exclude_exceptions: tuple = (),
    fallback_function: Optional[Callable] = None,
):
    """Decorator for applying circuit breaker pattern to a function"""

    def decorator(func: Callable) -> Callable:
        # Create circuit breaker for this function
        cb = CircuitBreaker(
            name=name or func.__name__,
            fail_max=fail_max,
            reset_timeout=reset_timeout,
            exclude_exceptions=exclude_exceptions,
            fallback_function=fallback_function,
        )

        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            return cb.execute(func, *args, **kwargs)

        # Attach circuit breaker to wrapper for access
        wrapper.circuit_breaker = cb

        return wrapper

    return decorator


# Pre-configured circuit breakers for common dependencies
class CircuitBreakers:
    """Pre-configured circuit breakers for AI4ALL-SRE dependencies"""

    # Ollama circuit breaker (longer timeout for LLM inference)
    ollama = CircuitBreaker(
        name="ollama",
        fail_max=3,
        reset_timeout=120.0,
        exclude_exceptions=(ValueError, KeyError),
    )

    # Redis circuit breaker (fast recovery)
    redis = CircuitBreaker(name="redis", fail_max=5, reset_timeout=30.0)

    # Kubernetes API circuit breaker
    k8s_api = CircuitBreaker(name="k8s_api", fail_max=3, reset_timeout=60.0)

    # Git operations circuit breaker
    git = CircuitBreaker(name="git", fail_max=2, reset_timeout=300.0)

    @classmethod
    def get_all_states(cls) -> dict:
        """Get states of all circuit breakers"""
        return {
            "ollama": cls.ollama.get_state(),
            "redis": cls.redis.get_state(),
            "k8s_api": cls.k8s_api.get_state(),
            "git": cls.git.get_state(),
        }
