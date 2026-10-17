#!/bin/bash
# Experimento de Idempotencia - Universidad de los Andes ARTI4208
# Script de instalación de prerequisitos (k6, kubectl, etc.)

echo "================================================================"
echo "   Setup de Prerequisitos - WSL2"
echo "================================================================"
echo ""

# Instalar k6
echo "[INFO] Instalando k6..."
if ! command -v k6 &> /dev/null; then
    sudo gpg -k
    sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
    sudo apt-get update
    sudo apt-get install -y k6
    echo "[OK] k6 instalado"
else
    echo "[OK] k6 ya está instalado"
fi
echo ""

# Verificar Docker
echo "[INFO] Verificando Docker..."
if docker info &> /dev/null; then
    echo "[OK] Docker está corriendo"
else
    echo "[WARN] Docker no está corriendo"
    echo "Por favor inicia Docker Desktop"
fi
echo ""

# Verificar kubectl
echo "[INFO] Verificando kubectl..."
if command -v kubectl &> /dev/null; then
    echo "[OK] kubectl instalado"
    kubectl version --client 2>&1 | head -1
else
    echo "[ERROR] kubectl no instalado"
    echo ""
    echo "Para instalar kubectl en WSL2:"
    echo "  curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
    echo "  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
fi
echo ""

# Verificar cluster disponible
echo "[INFO] Verificando cluster Kubernetes..."
if kubectl cluster-info &> /dev/null; then
    echo "[OK] Cluster accesible"
    kubectl config current-context
else
    echo "[ERROR] No hay cluster accesible"
    echo ""
    echo "Opciones para crear un cluster local:"
    echo ""
    echo "1. Docker Desktop con Kubernetes (Recomendado para Windows):"
    echo "   - Abrir Docker Desktop"
    echo "   - Settings -> Kubernetes -> Enable Kubernetes"
    echo ""
    echo "2. kind (Kubernetes in Docker):"
    echo "   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "   sudo install -o root -g root -m 0755 kind /usr/local/bin/kind"
    echo "   kind create cluster --name voltera-lab"
    echo ""
    echo "3. minikube:"
    echo "   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
    echo "   sudo install minikube-linux-amd64 /usr/local/bin/minikube"
    echo "   minikube start"
fi
echo ""

echo "================================================================"
echo "[OK] Setup completado"
echo ""
echo "Ejecuta nuevamente:"
echo "  ./scripts/idempotency/validate-setup.sh"
echo ""
