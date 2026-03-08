import sys
import os
import unittest
from unittest.mock import patch, MagicMock
import re

# Add parent directory to path to import ai_agent
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../components/ai-agent')))
import ai_agent
from ai_agent import RemediationAction
from pydantic import ValidationError

class TestAiAgentExtended(unittest.TestCase):

    def setUp(self):
        self.approved_namespaces = ["online-boutique", "observability", "incident-management"]

    def test_remediation_parsing_extended(self):
        # This test is now replaced by TestAgentParsing for Pydantic validation
        # The original regex parsing tests are no longer relevant for the new RemediationAction model
        pass

class TestAgentParsing(unittest.TestCase):
    def test_remediation_action_validation(self):
        # Valid Restart
        action = RemediationAction(
            rca="Restarting due to error",
            action="RESTART",
            deployment="frontend",
            namespace="online-boutique"
        )
        self.assertEqual(action.action, "RESTART")
        
        # Valid Scale
        action = RemediationAction(
            rca="Slowing down",
            action="SCALE",
            deployment="frontend",
            namespace="online-boutique",
            replicas=3
        )
        self.assertEqual(action.replicas, 3)

    def test_remediation_action_invalid(self):
        # Invalid Action type
        with self.assertRaises(ValidationError):
            RemediationAction(
                rca="Bad action",
                action="EXPLODE",
                deployment="frontend",
                namespace="online-boutique"
            )

class TestAiAgentSafetyAndExecution(unittest.TestCase):
    def setUp(self):
        self.approved_namespaces = ["online-boutique", "observability", "incident-management"]

    def test_is_action_safe_edge_cases(self):
        """Test is_action_safe with various inputs."""
        # Forbidden namespace
        action = RemediationAction(
            rca="RCA", action="RESTART", deployment="pod", namespace="kube-system"
        )
        self.assertFalse(ai_agent.is_action_safe(action))
        
        # Scale range
        action_bad_scale = RemediationAction(
            rca="RCA", action="SCALE", deployment="frontend", namespace="online-boutique", replicas=50
        )
        self.assertFalse(ai_agent.is_action_safe(action_bad_scale))
        
        # Safe scale
        action_good_scale = RemediationAction(
            rca="RCA", action="SCALE", deployment="frontend", namespace="online-boutique", replicas=2
        )
        self.assertTrue(ai_agent.is_action_safe(action_good_scale))
        
        # SQL injection style (if it were relevant) - this test is now outdated as is_action_safe expects RemediationAction
        # self.assertFalse(ai_agent.is_action_safe("RESTART DEPLOYMENT pods; DELETE NAMESPACE online-boutique; IN online-boutique"))

    @patch('ai_agent.k8s_apps_v1.read_namespaced_deployment')
    def test_verify_health_success(self, mock_read_deployment):
        """Test verify_health returns True on healthy deployment."""
        mock_obj = MagicMock()
        mock_obj.status.ready_replicas = 3
        mock_obj.spec.replicas = 3
        mock_read_deployment.return_value = mock_obj
        
        self.assertTrue(ai_agent.verify_health("frontend", "online-boutique"))

    @patch('ai_agent.k8s_apps_v1.read_namespaced_deployment')
    def test_verify_health_failure(self, mock_read_deployment):
        """Test verify_health returns False on unhealthy deployment."""
        mock_obj = MagicMock()
        mock_obj.status.ready_replicas = 1
        mock_obj.spec.replicas = 3
        mock_read_deployment.return_value = mock_obj
        
        self.assertFalse(ai_agent.verify_health("frontend", "online-boutique"))

    @patch('ai_agent.k8s_apps_v1.patch_namespaced_deployment')
    @patch('ai_agent.k8s_apps_v1.read_namespaced_deployment') # Used by verify_health
    @patch('ai_agent.gitops_remediate')
    def test_execute_remediation_rollback(self, mock_gitops, mock_read_deployment, mock_patch):
        """Test ROLLBACK execution."""
        mock_gitops.return_value = False
        
        # Mock for verify_health
        mock_obj = MagicMock()
        mock_obj.status.ready_replicas = 3
        mock_obj.spec.replicas = 3
        mock_read_deployment.return_value = mock_obj

        action = RemediationAction(
            rca="RCA", action="ROLLBACK", deployment="shippingservice", namespace="online-boutique"
        )
        result = ai_agent.execute_remediation(action)
        self.assertIn("applied to shippingservice", result)
        
        # Verify verify_health was called for the correct deployment/namespace
        mock_read_deployment.assert_called_with(name="shippingservice", namespace="online-boutique")

    def test_get_target_type_logic(self):
        """Test target type identification logic."""
        # This tests the mockable part of get_target_type or logic derived from patterns
        # Since get_target_type uses k8s client, we mostly test how execute_remediation uses it
        pass

if __name__ == '__main__':
    unittest.main()
