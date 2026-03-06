import unittest
from unittest.mock import patch, MagicMock
import configure_goalert
import json

class TestConfigureGoAlert(unittest.TestCase):

    @patch('configure_goalert.requests.post')
    def test_query_success(self, mock_post):
        """Test the GraphQL query wrapper for success."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"data": {"test": "ok"}}
        mock_post.return_value = mock_response
        
        result = configure_goalert.query("query { test }")
        self.assertEqual(result["data"]["test"], "ok")
        
        # Verify headers
        args, kwargs = mock_post.call_args
        self.assertIn('json', kwargs)
        self.assertEqual(kwargs['json']['query'], "query { test }")

    @patch('configure_goalert.requests.post')
    def test_query_failure(self, mock_post):
        """Test the GraphQL query wrapper for failure."""
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Error"
        mock_post.return_value = mock_response
        
        result = configure_goalert.query("query { test }")
        self.assertIsNone(result)

    @patch('configure_goalert.query')
    @patch('builtins.open', new_callable=MagicMock)
    @patch('builtins.print')
    def test_main_flow(self, mock_print, mock_open, mock_query):
        """Test the full configuration flow with mocks."""
        # 1. Create Escalation Policy
        # 2. Create Service
        # 3. Add Integration Key
        mock_query.side_effect = [
            {"data": {"createEscalationPolicy": {"id": "ep-123"}}},
            {"data": {"createService": {"id": "svc-456"}}},
            {"data": {"createIntegrationKey": {"id": "key-789", "href": "http://goalert.com/key"}}}
        ]
        
        configure_goalert.main()
        
        self.assertEqual(mock_query.call_count, 3)
        mock_open.assert_called_with("/tmp/goalert_integration_url", "w")
        mock_open.return_value.__enter__.return_value.write.assert_called_with("http://goalert.com/key")

if __name__ == '__main__':
    unittest.main()
