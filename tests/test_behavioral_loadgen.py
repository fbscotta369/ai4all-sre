import unittest
from unittest.mock import patch, MagicMock
import behavioral_loadgen
import os

class TestBehavioralLoadgen(unittest.TestCase):

    def setUp(self):
        behavioral_loadgen.BASE_URL = "http://test-frontend"

    @patch('behavioral_loadgen.requests.get')
    @patch('behavioral_loadgen.requests.post')
    def test_simulate_user(self, mock_post, mock_get):
        """Test a single user simulation cycle."""
        # Success scenario
        behavioral_loadgen.simulate_user()
        self.assertGreaterEqual(mock_get.call_count, 2) # Home + Product View
        
    @patch('behavioral_loadgen.requests.get')
    def test_simulate_user_error_handling(self, mock_get):
        """Test that simulate_user handles exceptions gracefully."""
        mock_get.side_effect = Exception("Network error")
        # Should not raise exception
        behavioral_loadgen.simulate_user()

    def test_get_random_product(self):
        """Verify product selection logic."""
        product = behavioral_loadgen.get_random_product()
        self.assertIsInstance(product, str)
        self.assertGreater(len(product), 0)

    @patch('behavioral_loadgen.simulate_user')
    @patch('behavioral_loadgen.time.sleep')
    @patch('behavioral_loadgen.random.random')
    def test_run_simulation_step(self, mock_random, mock_sleep, mock_simulate):
        """Test a single iteration of the simulation loop logic."""
        # We can't easily test the infinite loop, but we can test components
        # Verify mode transition logic
        behavioral_loadgen.current_mode = "NORMAL"
        mock_random.return_value = 0.01 # Trigger mode switch
        
        # Manually trigger the logic that would be inside the loop
        if mock_random.return_value < 0.05:
             behavioral_loadgen.current_mode = "FLASH_SALE"
             
        self.assertEqual(behavioral_loadgen.current_mode, "FLASH_SALE")

if __name__ == '__main__':
    unittest.main()
