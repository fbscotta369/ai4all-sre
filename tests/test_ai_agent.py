import sys
import os
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import ai_agent

class TestAiAgent(unittest.TestCase):

    def test_is_action_safe_allowed(self):
        """Verify that safe actions in approved namespaces are allowed."""
        self.assertTrue(ai_agent.is_action_safe("RESTART DEPLOYMENT frontend IN online-boutique"))
        self.assertTrue(ai_agent.is_action_safe("SCALE DEPLOYMENT adservice IN online-boutique TO 3"))

    def test_is_action_safe_forbidden_keyword(self):
        """Verify that actions with forbidden keywords are blocked."""
        self.assertFalse(ai_agent.is_action_safe("DELETE NAMESPACE online-boutique"))
        self.assertFalse(ai_agent.is_action_safe("RESTART DEPLOYMENT kube-system-pod IN kube-system"))

    def test_is_action_safe_forbidden_namespace(self):
        """Verify that actions targeting non-approved namespaces are blocked."""
        self.assertFalse(ai_agent.is_action_safe("RESTART DEPLOYMENT my-app IN default"))

    @patch('ai_agent.get_target_type')
    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    @patch('ai_agent.verify_health')
    def test_execute_remediation_restart(self, mock_health, mock_patch, mock_get_type):
        """Test the RESTART DEPLOYMENT regex and execution."""
        mock_get_type.return_value = ('deployment', MagicMock())
        mock_health.return_value = True
        
        result = ai_agent.execute_remediation("RESTART DEPLOYMENT frontend IN online-boutique")
        
        self.assertIn("Successfully restarted", result)
        self.assertTrue(mock_patch.called)

    @patch('ai_agent.get_target_type')
    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    def test_execute_remediation_scale(self, mock_patch, mock_get_type):
        """Test the SCALE DEPLOYMENT regex and execution."""
        mock_get_type.return_value = ('deployment', MagicMock())
        
        result = ai_agent.execute_remediation("SCALE DEPLOYMENT frontend IN online-boutique TO 5")
        
        self.assertIn("Successfully scaled", result)
        # Check if the body contains the correct replica count
        args, kwargs = mock_patch.call_args
        self.assertEqual(kwargs['body']['spec']['replicas'], 5)

if __name__ == '__main__':
    unittest.main()
