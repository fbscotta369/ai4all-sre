import sys
import os
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# Add paths to PYTHONPATH for imports to work
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../components/ai-agent')))
import ai_agent
from ai_agent import RemediationAction

class TestAiAgent(unittest.TestCase):

    def test_is_action_safe_allowed(self):
        """Verify that safe actions in approved namespaces are allowed."""
        action = RemediationAction(
            rca="Test RCA",
            action="RESTART",
            deployment="frontend",
            namespace="online-boutique"
        )
        self.assertTrue(ai_agent.is_action_safe(action))
        
        action_scale = RemediationAction(
            rca="Test RCA",
            action="SCALE",
            deployment="adservice",
            namespace="online-boutique",
            replicas=3
        )
        self.assertTrue(ai_agent.is_action_safe(action_scale))

    def test_is_action_safe_forbidden_namespace(self):
        """Verify that actions targeting forbidden namespaces are blocked."""
        action = RemediationAction(
            rca="Test RCA",
            action="RESTART",
            deployment="kube-system-pod",
            namespace="kube-system"
        )
        self.assertFalse(ai_agent.is_action_safe(action))

    def test_is_action_safe_not_in_approved_list(self):
        """Verify that actions targeting non-approved namespaces are blocked."""
        action = RemediationAction(
            rca="Test RCA",
            action="RESTART",
            deployment="my-app",
            namespace="default"
        )
        self.assertFalse(ai_agent.is_action_safe(action))

    @patch('ai_agent.get_target_type')
    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    @patch('ai_agent.verify_health')
    @patch('ai_agent.gitops_remediate')
    def test_execute_remediation_restart(self, mock_gitops, mock_health, mock_patch, mock_get_type):
        """Test the RESTART execution."""
        mock_gitops.return_value = False # Force fallback to direct patch
        mock_get_type.return_value = ('deployment', MagicMock())
        mock_health.return_value = True
        
        action = RemediationAction(
            rca="Test RCA",
            action="RESTART",
            deployment="frontend",
            namespace="online-boutique"
        )
        result = ai_agent.execute_remediation(action)
        
        self.assertIn("applied to frontend", result)
        self.assertTrue(mock_patch.called)

    @patch('ai_agent.get_target_type')
    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    @patch('ai_agent.gitops_remediate')
    def test_execute_remediation_scale(self, mock_gitops, mock_patch, mock_get_type):
        """Test the SCALE execution."""
        mock_gitops.return_value = False # Force fallback to direct patch
        mock_get_type.return_value = ('deployment', MagicMock())
        
        action = RemediationAction(
            rca="Test RCA",
            action="SCALE",
            deployment="frontend",
            namespace="online-boutique",
            replicas=5
        )
        result = ai_agent.execute_remediation(action)
        
        self.assertIn("applied to frontend", result)
        # Check if the body contains the correct replica count
        args, kwargs = mock_patch.call_args
        self.assertEqual(kwargs['body']['spec']['replicas'], 5)

if __name__ == '__main__':
    unittest.main()
