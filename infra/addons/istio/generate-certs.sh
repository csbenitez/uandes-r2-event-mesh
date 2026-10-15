#!/usr/bin/env bash
# ==============================================================================
# Generador de Certificados TLS para Ingress Gateway de Istio (HTTPS 443)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERT_DIR"

PUBLIC_IP="${1:-}"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(kubectl get svc istio-ingress -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '57.166.131.119')"
fi

echo "Generando certificado TLS para IP: $PUBLIC_IP..."

cat <<EOF > "$CERT_DIR/san.cnf"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CO
ST = Bogota
L = Bogota
O = Voltera Energy
OU = Security Zero Trust
CN = $PUBLIC_IP

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $PUBLIC_IP
IP.2 = 127.0.0.1
DNS.1 = voltera-dev-mesh.eastus2.cloudapp.azure.com
DNS.2 = *.eastus2.cloudapp.azure.com
DNS.3 = $PUBLIC_IP.sslip.io
DNS.4 = *.sslip.io
DNS.5 = localhost
EOF

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt" \
  -config "$CERT_DIR/san.cnf"

echo "Aplicando Secret 'voltera-ingress-cert' en Kubernetes..."
kubectl create secret tls voltera-ingress-cert --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" -n istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls voltera-ingress-cert --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" -n voltera --dry-run=client -o yaml | kubectl apply -f -

echo "Certificados listos y cargados en istio-system y voltera."
