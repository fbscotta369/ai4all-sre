#!/bin/bash
set -e

# Linkerd 2.14+ compliant certificate generation
TRUST_ANCHOR_CERT="trust-anchor.crt"
TRUST_ANCHOR_KEY="trust-anchor.key"
ISSUER_CERT="issuer.crt"
ISSUER_KEY="issuer.key"

# 1. Create Trust Anchor (Self-signed Root CA)
openssl req -x509 -newkey rsa:4096 -keyout $TRUST_ANCHOR_KEY -out $TRUST_ANCHOR_CERT -nodes -days 3650 \
  -subj "/CN=root.linkerd.cluster.local" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign,digitalSignature"

# 2. Create Issuer Private Key & CSR
openssl req -newkey rsa:4096 -keyout $ISSUER_KEY -out issuer.csr -nodes \
  -subj "/CN=identity.linkerd.cluster.local"

# 3. Create Extension File for Issuer (Crucial for Linkerd)
cat > issuer.ext <<EOF
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign,digitalSignature
subjectAltName=DNS:identity.linkerd.cluster.local
EOF

# 4. Sign Issuer Certificate with Trust Anchor
openssl x509 -req -in issuer.csr -CA $TRUST_ANCHOR_CERT -CAkey $TRUST_ANCHOR_KEY -CAcreateserial \
  -out $ISSUER_CERT -days 365 -extfile issuer.ext

echo "[*] Zero Trust Certificates (mTLS) generated successfully for the lab."
