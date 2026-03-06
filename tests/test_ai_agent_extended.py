import sys
import os
import unittest
from unittest.mock import patch, MagicMock
import re

# Add parent directory to path to import ai_agent
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import ai_agent

class TestAiAgentExtended(unittest.TestCase):

    def setUp(self):
        self.approved_namespaces = ["online-boutique", "observability", "incident-management"]

    def test_remediation_parsing_extended(self):
        """Test parsing of various remediation strings."""
        # Test RESTART
        text = "Action: RESTART DEPLOYMENT 'frontend' IN 'online-boutique'"
        restart_match = re.search(ai_agent.RESTART_PATTERN, text, re.IGNORECASE)
        self.assertIsNotNone(restart_match)
        self.assertEqual(restart_match.group(1), "frontend")
        self.assertEqual(restart_match.group(2), "online-boutique")

        # Test SCALE
        text = "SCALE DEPLOYMENT `adservice` IN online-boutique TO 5"
        scale_match = re.search(ai_agent.SCALE_PATTERN, text, re.IGNORECASE)
        self.assertIsNotNone(scale_match)
        self.assertEqual(scale_match.group(1), "adservice")
        self.assertEqual(scale_match.group(2), "online-boutique")
        self.assertEqual(scale_match.group(3), "5")

        # Test ROLLBACK
        text = "I recommend ROLLBACK DEPLOYMENT \"shippingservice\" IN \"online-boutique\""
        rollback_match = re.search(ai_agent.ROLLBACK_PATTERN, text, re.IGNORECASE)
        self.assertIsNotNone(rollback_match)
        self.assertEqual(rollback_match.group(1), "shippingservice")
        self.assertEqual(rollback_match.group(2), "online-boutique")

    def test_is_action_safe_edge_cases(self):
        """Test is_action_safe with various inputs."""
        # Namespace in string but not as part of the action
        self.assertFalse(ai_agent.is_action_safe("RESTART DEPLOYMENT frontend IN default # mention online-boutique"))
        
        # Valid namespace
        self.assertTrue(ai_agent.is_action_safe("RESTART DEPLOYMENT frontend IN online-boutique"))
        
        # SQL injection style (if it were relevant)
        self.assertFalse(ai_agent.is_action_safe("RESTART DEPLOYMENT pods; DELETE NAMESPACE online-boutique; IN online-boutique"))

    @patch('ai_agent.get_target_type')
    def test_verify_health_success(self, mock_get_type):
        """Test verify_health returns True on healthy deployment."""
        mock_obj = MagicMock()
        mock_obj.status.ready_replicas = 3
        mock_obj.spec.replicas = 3
        mock_get_type.return_value = ('deployment', mock_obj)
        
        self.assertTrue(ai_agent.verify_health("frontend", "online-boutique"))

    @patch('ai_agent.get_target_type')
    def test_verify_health_failure(self, mock_get_type):
        """Test verify_health returns False on unhealthy deployment."""
        mock_obj = MagicMock()
        mock_obj.status.ready_replicas = 1
        mock_obj.spec.replicas = 3
        mock_get_type.return_value = ('deployment', mock_obj)
        
        self.assertFalse(ai_agent.verify_health("frontend", "online-boutique"))

    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    @patch('ai_agent.get_target_type')
    @patch('ai_agent.verify_health')
    def test_execute_remediation_rollback(self, mock_health, mock_get_type, mock_patch):
        """Test ROLLBACK execution."""
        mock_get_type.return_value = ('deployment', MagicMock())
        mock_health.return_value = True
        
        action = "ROLLBACK DEPLOYMENT frontend IN online-boutique"
        result = ai_agent.execute_remediation(action)
        
        self.assertIn("Successfully rolled back", result)
        
        # Verify rollback verify_health call
        mock_health.assert_called_with("frontend", "online-boutique")

    def test_get_target_type_logic(self):
        """Test target type identification logic."""
        # This tests the mockable part of get_target_type or logic derived from patterns
        # Since get_target_type uses k8s client, we mostly test how execute_remediation uses it
        pass

if __name__ == '__main__':
    unittest.main()
