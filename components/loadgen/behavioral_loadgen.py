import requests
import time
import random
import os
import signal
import sys
import json
import threading
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional
from datetime import datetime
from contextlib import contextmanager

# Prometheus metrics (if available)
try:
    from prometheus_client import (
        Counter,
        Histogram,
        Gauge,
        start_http_server,
        generate_latest,
    )

    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False
    print(
        "[!] prometheus_client not installed. Metrics will be logged only.", flush=True
    )

FRONTEND_ADDR = os.getenv("FRONTEND_ADDR", "frontend:80")
BASE_URL = f"http://{FRONTEND_ADDR}"
METRICS_PORT = int(os.getenv("METRICS_PORT", "9090"))

# Simulation Modes
MODES = ["NORMAL", "FLASH_SALE", "BOT_ATTACK", "CHAOS_TEST"]
current_mode = "NORMAL"

# Chaos injection settings
CHAOS_ENABLED = os.getenv("CHAOS_ENABLED", "false").lower() == "true"
CHAOS_PROBABILITY = float(os.getenv("CHAOS_PROBABILITY", "0.1"))
CHAOS_TYPES = ["http_500", "timeout", "slow_response", "connection_error"]


@dataclass
class RequestMetrics:
    """Track request metrics"""

    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_latency_ms: float = 0
    min_latency_ms: float = float("inf")
    max_latency_ms: float = 0
    status_codes: Dict[int, int] = None

    def __post_init__(self):
        if self.status_codes is None:
            self.status_codes = {}

    def record_request(self, latency_ms: float, status_code: int, success: bool):
        self.total_requests += 1
        self.total_latency_ms += latency_ms
        self.min_latency_ms = min(self.min_latency_ms, latency_ms)
        self.max_latency_ms = max(self.max_latency_ms, latency_ms)

        if success:
            self.successful_requests += 1
        else:
            self.failed_requests += 1

        self.status_codes[status_code] = self.status_codes.get(status_code, 0) + 1

    def get_avg_latency(self) -> float:
        return self.total_latency_ms / max(self.total_requests, 1)

    def get_success_rate(self) -> float:
        return self.successful_requests / max(self.total_requests, 1) * 100

    def to_dict(self) -> dict:
        return {
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "success_rate_percent": self.get_success_rate(),
            "avg_latency_ms": self.get_avg_latency(),
            "min_latency_ms": self.min_latency_ms if self.total_requests > 0 else 0,
            "max_latency_ms": self.max_latency_ms,
            "status_codes": self.status_codes,
        }


class MetricsCollector:
    """Collect and expose metrics"""

    def __init__(self):
        self.metrics = RequestMetrics()
        self.mode_metrics = {mode: RequestMetrics() for mode in MODES}
        self._lock = threading.Lock()

        if PROMETHEUS_AVAILABLE:
            # Prometheus metrics
            self.requests_total = Counter(
                "loadgen_requests_total", "Total requests", ["mode", "status"]
            )
            self.request_duration = Histogram(
                "loadgen_request_duration_seconds", "Request duration", ["mode"]
            )
            self.active_users = Gauge("loadgen_active_users", "Active simulated users")
            self.error_rate = Gauge(
                "loadgen_error_rate", "Error rate percentage", ["mode"]
            )

            # Start metrics server
            start_http_server(METRICS_PORT)
            print(
                f"[*] Prometheus metrics server started on port {METRICS_PORT}",
                flush=True,
            )

    def record(self, mode: str, latency_ms: float, status_code: int, success: bool):
        with self._lock:
            self.metrics.record_request(latency_ms, status_code, success)
            self.mode_metrics[mode].record_request(latency_ms, status_code, success)

            if PROMETHEUS_AVAILABLE:
                status = "success" if success else "failure"
                self.requests_total.labels(mode=mode, status=status).inc()
                self.request_duration.labels(mode=mode).observe(latency_ms / 1000)
                self.error_rate.labels(mode=mode).set(
                    100 - self.mode_metrics[mode].get_success_rate()
                )

    def get_summary(self) -> dict:
        with self._lock:
            return {
                "overall": self.metrics.to_dict(),
                "by_mode": {mode: m.to_dict() for mode, m in self.mode_metrics.items()},
                "timestamp": datetime.utcnow().isoformat(),
            }

    def log_summary(self):
        summary = self.get_summary()
        print("\n" + "=" * 60, flush=True)
        print("📊 LOAD GENERATOR METRICS SUMMARY", flush=True)
        print("=" * 60, flush=True)
        print(f"Total Requests: {summary['overall']['total_requests']}", flush=True)
        print(
            f"Success Rate: {summary['overall']['success_rate_percent']:.1f}%",
            flush=True,
        )
        print(f"Avg Latency: {summary['overall']['avg_latency_ms']:.1f}ms", flush=True)
        print(f"Active Mode: {current_mode}", flush=True)
        print("=" * 60, flush=True)


# Global metrics collector
metrics = MetricsCollector()


def get_random_product():
    products = [
        "0PUK6V6EV0",
        "1Y7S7KQL9K",
        "2914S8S169",
        "66VCHS6S6S",
        "6E92Z96TS0",
        "9SI62X9S6S",
        "L98S9S9S6S",
        "LSV92X9S6S",
        "OLJ6S6S6S6",
    ]
    return random.choice(products)


@contextmanager
def request_timer(mode: str):
    """Context manager to track request latency"""
    start_time = time.time()
    success = True
    status_code = 200

    try:
        yield
    except requests.exceptions.Timeout:
        success = False
        status_code = 408
    except requests.exceptions.ConnectionError:
        success = False
        status_code = 503
    except Exception as e:
        success = False
        status_code = 500
        print(f"Request error: {e}", flush=True)
    finally:
        latency_ms = (time.time() - start_time) * 1000
        metrics.record(mode, latency_ms, status_code, success)


def inject_chaos():
    """Inject chaos based on current settings"""
    if not CHAOS_ENABLED or random.random() > CHAOS_PROBABILITY:
        return None

    chaos_type = random.choice(CHAOS_TYPES)

    if chaos_type == "http_500":
        # Simulate HTTP 500 by raising an exception
        raise Exception("Chaos: Simulated HTTP 500")
    elif chaos_type == "timeout":
        # Sleep to simulate timeout
        time.sleep(10)
        raise requests.exceptions.Timeout("Chaos: Simulated timeout")
    elif chaos_type == "slow_response":
        # Add artificial delay
        time.sleep(random.uniform(1, 3))
    elif chaos_type == "connection_error":
        # Simulate connection error
        raise requests.exceptions.ConnectionError("Chaos: Simulated connection error")

    return None


def simulate_user():
    """Simulate a realistic user journey with metrics tracking"""
    mode = current_mode

    # Adjust behavior based on mode
    think_time = {
        "NORMAL": (0.5, 2.0),
        "FLASH_SALE": (0.1, 0.5),
        "BOT_ATTACK": (0.01, 0.05),
        "CHAOS_TEST": (0.5, 1.0),
    }

    min_think, max_think = think_time.get(mode, (0.5, 2.0))

    try:
        # Home page
        with request_timer(mode):
            if CHAOS_ENABLED and mode == "CHAOS_TEST":
                inject_chaos()
            response = requests.get(BASE_URL, timeout=5)

        # View product
        product_id = get_random_product()
        with request_timer(mode):
            if CHAOS_ENABLED and mode == "CHAOS_TEST":
                inject_chaos()
            response = requests.get(f"{BASE_URL}/product/{product_id}", timeout=5)

        # Add to cart (50% chance)
        if random.random() > 0.5:
            with request_timer(mode):
                if CHAOS_ENABLED and mode == "CHAOS_TEST":
                    inject_chaos()
                response = requests.post(
                    f"{BASE_URL}/cart",
                    data={"product_id": product_id, "quantity": random.randint(1, 4)},
                    timeout=5,
                )

        # Checkout (20% chance)
        if random.random() > 0.8:
            with request_timer(mode):
                if CHAOS_ENABLED and mode == "CHAOS_TEST":
                    inject_chaos()
                response = requests.get(f"{BASE_URL}/cart/checkout", timeout=5)

        # Realistic think time between actions
        time.sleep(random.uniform(min_think, max_think))

    except Exception as e:
        print(f"Error in user simulation ({mode} mode): {e}", flush=True)


def run_simulation():
    global current_mode
    print(f"Starting Behavioral Load Generator in {current_mode} mode...")
    print(f"Metrics available at http://localhost:{METRICS_PORT}/metrics", flush=True)
    if CHAOS_ENABLED:
        print(f"Chaos injection enabled (probability: {CHAOS_PROBABILITY})", flush=True)

    iteration = 0
    last_metrics_log = time.time()

    while True:
        iteration += 1

        # Log metrics every 60 seconds
        if time.time() - last_metrics_log > 60:
            metrics.log_summary()
            last_metrics_log = time.time()

        # Occasionally change mode (5% chance)
        if random.random() < 0.05:
            old_mode = current_mode
            current_mode = random.choice(MODES)
            print(f"--- Mode switched: {old_mode} → {current_mode} ---", flush=True)
            metrics.active_users.set(1 if current_mode == "FLASH_SALE" else 0)

        if current_mode == "NORMAL":
            simulate_user()

        elif current_mode == "FLASH_SALE":
            # High frequency of users - simulate multiple concurrent users
            threads = []
            for _ in range(5):
                t = threading.Thread(target=simulate_user)
                t.start()
                threads.append(t)

            # Wait for threads to complete
            for t in threads:
                t.join(timeout=10)

            time.sleep(0.1)

        elif current_mode == "BOT_ATTACK":
            # Very high frequency of specific page hits
            try:
                with request_timer(current_mode):
                    if CHAOS_ENABLED:
                        inject_chaos()
                    response = requests.get(BASE_URL, timeout=2)
            except:
                pass
            time.sleep(0.01)

        elif current_mode == "CHAOS_TEST":
            # Special mode for testing resilience
            simulate_user()
            time.sleep(0.5)


def signal_handler(sig, frame):
    print("Shutting down Behavioral Load Generator...")
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    run_simulation()
