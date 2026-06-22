#!/usr/bin/env bash
# =============================================================================
# Self-signed certificate generator for the Keycloak prod-test simulation
# =============================================================================
# Creates a private CA and a server certificate for `keycloak.localhost`.
#
#   - keycloak-ca.crt / keycloak-ca.key  -> the local Certificate Authority
#   - keycloak.crt    / keycloak.key     -> the Keycloak server certificate
#
# Keycloak serves TLS with keycloak.crt + keycloak.key.
# The auth service trusts keycloak-ca.crt via SSL_CERT_FILE so that
# KEYCLOAK_SSL_VERIFY=true validates the chain (production-like).
#
# Usage:
#   ./keycloak-certs/generate-certs.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

DOMAIN="keycloak.localhost"
SERVER_DAYS=825
CA_DAYS=3650

echo "==> Generating local CA"
openssl genrsa -out keycloak-ca.key 4096
openssl req -x509 -new -nodes -key keycloak-ca.key -sha256 -days "${CA_DAYS}" \
  -subj "/C=AR/O=Evo CRM Local/CN=Evo CRM Local Root CA" \
  -out keycloak-ca.crt

echo "==> Generating server key + CSR for ${DOMAIN}"
openssl genrsa -out keycloak.key 2048
openssl req -new -key keycloak.key \
  -subj "/C=AR/O=Evo CRM Local/CN=${DOMAIN}" \
  -out keycloak.csr

echo "==> Writing SAN extension"
cat > keycloak.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = localhost
DNS.3 = keycloak
IP.1  = 127.0.0.1
EOF

echo "==> Signing server certificate with the CA"
openssl x509 -req -in keycloak.csr -CA keycloak-ca.crt -CAkey keycloak-ca.key \
  -CAcreateserial -out keycloak.crt -days "${SERVER_DAYS}" -sha256 \
  -extfile keycloak.ext

# Keycloak runs as a non-root user (UID 1000); make the cert/key world-readable.
chmod 644 keycloak.key keycloak.crt keycloak-ca.crt

echo "==> Done. Files in $(pwd):"
ls -1 keycloak-ca.crt keycloak.crt keycloak.key
