import unittest
from unittest.mock import patch, MagicMock, mock_open
import generate_certs
import datetime
import os

class TestGenerateCerts(unittest.TestCase):

    @patch('generate_certs.os.path.exists')
    @patch('generate_certs.x509.load_pem_x509_certificate')
    @patch('builtins.open', new_callable=mock_open, read_data=b"fake-cert")
    def test_verify_certs_success(self, mock_file, mock_load, mock_exists):
        """Test verify_certs when all files exist and are valid."""
        mock_exists.return_value = True
        
        # Mock certificate objects
        mock_cert = MagicMock()
        mock_cert.not_valid_after = datetime.datetime.utcnow() + datetime.timedelta(days=10)
        mock_load.return_value = mock_cert
        
        self.assertTrue(generate_certs.verify_certs())

    @patch('generate_certs.os.path.exists')
    def test_verify_certs_missing_file(self, mock_exists):
        """Test verify_certs when a file is missing."""
        mock_exists.side_effect = lambda x: x != "issuer.crt"
        self.assertFalse(generate_certs.verify_certs())

    @patch('generate_certs.verify_certs')
    @patch('generate_certs.ec.generate_private_key')
    @patch('generate_certs.x509.CertificateBuilder')
    @patch('builtins.open', new_callable=mock_open)
    def test_generate_cert_flow(self, mock_file, mock_builder, mock_gen_key, mock_verify):
        """Test the generation flow (mocking crypto calls)."""
        mock_verify.return_value = False
        
        # Mocking complex builder pattern is hard, so we just verify it's called
        mock_builder.return_value.subject_name.return_value.issuer_name.return_value.public_key.return_value.serial_number.return_value.not_valid_before.return_value.not_valid_after.return_value.add_extension.return_value.sign.return_value.public_bytes.return_value = b"cert-data"
        
        generate_certs.generate_cert(force=True)
        
        self.assertGreaterEqual(mock_file.call_count, 4) # 2 keys + 2 crts

if __name__ == '__main__':
    unittest.main()
