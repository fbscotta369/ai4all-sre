import datetime
import os
import sys
import argparse
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization

def verify_certs():
    """Validates if the existing certificates are present and valid."""
    required_files = ["trust-anchor.crt", "trust-anchor.key", "issuer.crt", "issuer.key"]
    for f in required_files:
        if not os.path.exists(f):
            print(f"[-] Missing file: {f}")
            return False
    
    try:
        # Check Trust Anchor
        with open("trust-anchor.crt", "rb") as f:
            root_cert = x509.load_pem_x509_certificate(f.read())
        
        # Check Issuer
        with open("issuer.crt", "rb") as f:
            issuer_cert = x509.load_pem_x509_certificate(f.read())
        
        now = datetime.datetime.utcnow()
        if root_cert.not_valid_after < now:
            print("[-] Trust Anchor has expired.")
            return False
        if issuer_cert.not_valid_after < now:
            print("[-] Issuer certificate has expired.")
            return False
            
        print("[+] Certificates are present and valid.")
        return True
    except Exception as e:
        print(f"[-] Error validating certificates: {e}")
        return False

def generate_cert(force=False):
    if not force and verify_certs():
        print("[!] Valid certificates already exist. Use --force to overwrite.")
        return

    print("[*] Generating new Linkerd certificates...")
    try:
        # Generate Trust Anchor
        root_key = ec.generate_private_key(ec.SECP256R1())
        root_subject = root_issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, u"root.linkerd.cluster.local"),
        ])
        root_cert = x509.CertificateBuilder().subject_name(
            root_subject
        ).issuer_name(
            root_issuer
        ).public_key(
            root_key.public_key()
        ).serial_number(
            x509.random_serial_number()
        ).not_valid_before(
            datetime.datetime.utcnow()
        ).not_valid_after(
            # Valid for 10 years
            datetime.datetime.utcnow() + datetime.timedelta(days=3650)
        ).add_extension(
            x509.BasicConstraints(ca=True, path_length=1), critical=True,
        ).sign(root_key, hashes.SHA256())

        with open("trust-anchor.key", "wb") as f:
            f.write(root_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption(),
            ))
        with open("trust-anchor.crt", "wb") as f:
            f.write(root_cert.public_bytes(serialization.Encoding.PEM))

        # Generate Issuer
        issuer_key = ec.generate_private_key(ec.SECP256R1())
        issuer_subject = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, u"identity.linkerd.cluster.local"),
        ])
        issuer_cert = x509.CertificateBuilder().subject_name(
            issuer_subject
        ).issuer_name(
            root_subject
        ).public_key(
            issuer_key.public_key()
        ).serial_number(
            x509.random_serial_number()
        ).not_valid_before(
            datetime.datetime.utcnow()
        ).not_valid_after(
            datetime.datetime.utcnow() + datetime.timedelta(days=365)
        ).add_extension(
            x509.BasicConstraints(ca=True, path_length=0), critical=True,
        ).sign(root_key, hashes.SHA256())

        with open("issuer.key", "wb") as f:
            f.write(issuer_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption(),
            ))
        with open("issuer.crt", "wb") as f:
            f.write(issuer_cert.public_bytes(serialization.Encoding.PEM))

        print("[+] Linkerd certificates generated successfully.")
    except Exception as e:
        print(f"[!] Critical Error generating certificates: {e}")
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Linkerd Certificate Manager")
    parser.add_argument("--verify", action="store_true", help="Verify existing certificates")
    parser.add_argument("--force", action="store_true", help="Force regeneration of certificates")
    args = parser.parse_args()

    if args.verify:
        if verify_certs():
            sys.exit(0)
        else:
            sys.exit(1)
    
    generate_cert(force=args.force)
