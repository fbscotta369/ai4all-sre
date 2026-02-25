import requests
import time
import random
import os
import signal
import sys

FRONTEND_ADDR = os.getenv("FRONTEND_ADDR", "frontend:80")
BASE_URL = f"http://{FRONTEND_ADDR}"

# Simulation Modes
MODES = ["NORMAL", "FLASH_SALE", "BOT_ATTACK"]
current_mode = "NORMAL"

def get_random_product():
    products = ["0PUK6V6EV0", "1Y7S7KQL9K", "2914S8S169", "66VCHS6S6S", "6E92Z96TS0", "9SI62X9S6S", "L98S9S9S6S", "LSV92X9S6S", "OLJ6S6S6S6"]
    return random.choice(products)

def simulate_user():
    try:
        # Home page
        requests.get(BASE_URL, timeout=5)
        
        # View product
        product_id = get_random_product()
        requests.get(f"{BASE_URL}/product/{product_id}", timeout=5)
        
        # Add to cart
        if random.random() > 0.5:
            requests.post(f"{BASE_URL}/cart", data={"product_id": product_id, "quantity": random.randint(1, 4)}, timeout=5)
            
        # Checkout
        if random.random() > 0.8:
            requests.get(f"{BASE_URL}/cart/checkout", timeout=5)
    except Exception as e:
        print(f"Error in user simulation: {e}")

def run_simulation():
    global current_mode
    print(f"Starting Behavioral Load Generator in {current_mode} mode...")
    
    while True:
        # Occasionally change mode
        if random.random() < 0.05:
            current_mode = random.choice(MODES)
            print(f"--- Mode switched to: {current_mode} ---")

        if current_mode == "NORMAL":
            simulate_user()
            time.sleep(random.uniform(0.5, 2.0))
        
        elif current_mode == "FLASH_SALE":
            # High frequency of users
            for _ in range(5):
                simulate_user()
            time.sleep(0.1)
            
        elif current_mode == "BOT_ATTACK":
            # Very high frequency of specific page hits
            try:
                requests.get(BASE_URL, timeout=2)
            except:
                pass
            time.sleep(0.01)

def signal_handler(sig, frame):
    print("Shutting down Behavioral Load Generator...")
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    run_simulation()
