<#
.SYNOPSIS
    Genera el certificado TLS autofirmado con SANs y crea el Kubernetes Secret 'voltera-ingress-cert'
    para habilitar cifrado HTTPS en el Ingress Gateway de Istio.
.PARAMETER PublicIp
    IP pública o host del Ingress (por defecto busca la IP de istio-ingress en AKS o usa 57.166.131.119).
.PARAMETER ApplySecret
    Si está presente, aplica automáticamente el Secret en los namespaces 'istio-system' y 'voltera'.
#>

[CmdletBinding()]
param(
    [string]$PublicIp = "",
    [switch]$ApplySecret = $true
)

$ErrorActionPreference = "Stop"

# 1. Determinar IP pública
if (-not $PublicIp) {
    try {
        $ip = kubectl get svc istio-ingress -n istio-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
        if ($ip) { $PublicIp = $ip }
    } catch {}
}
if (-not $PublicIp) { $PublicIp = "57.166.131.119" }

Write-Host "Generando certificado TLS para IP: $PublicIp..." -ForegroundColor Cyan

# 2. Localizar OpenSSL
$openssl = "openssl"
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\Git\usr\bin\openssl.exe") {
        $openssl = "C:\Program Files\Git\usr\bin\openssl.exe"
    } else {
        throw "OpenSSL no está en el PATH ni en la ruta predeterminada de Git."
    }
}

$certDir = "$PSScriptRoot\certs"
if (-not (Test-Path $certDir)) { New-Item -ItemType Directory -Path $certDir -Force | Out-Null }

$cnfContent = @"
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
CN = $PublicIp

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $PublicIp
IP.2 = 127.0.0.1
DNS.1 = voltera-dev-mesh.eastus2.cloudapp.azure.com
DNS.2 = *.eastus2.cloudapp.azure.com
DNS.3 = $PublicIp.sslip.io
DNS.4 = *.sslip.io
DNS.5 = localhost
"@

$cnfPath = "$certDir\san.cnf"
Set-Content -Path $cnfPath -Value $cnfContent

& $openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$certDir\tls.key" -out "$certDir\tls.crt" -config $cnfPath

Write-Host "Certificados generados en ${certDir}:" -ForegroundColor Green
Write-Host "  -> tls.crt" -ForegroundColor Gray
Write-Host "  -> tls.key" -ForegroundColor Gray

# 3. Aplicar Secret en Kubernetes
if ($ApplySecret) {
    Write-Host "`nAplicando Secret 'voltera-ingress-cert' en AKS..." -ForegroundColor Yellow
    & kubectl create secret tls voltera-ingress-cert --cert="$certDir\tls.crt" --key="$certDir\tls.key" -n istio-system --dry-run=client -o yaml | kubectl apply -f -
    & kubectl create secret tls voltera-ingress-cert --cert="$certDir\tls.crt" --key="$certDir\tls.key" -n voltera --dry-run=client -o yaml | kubectl apply -f -
    Write-Host "¡Secret TLS configurado exitosamente en istio-system y voltera!" -ForegroundColor Green
}
