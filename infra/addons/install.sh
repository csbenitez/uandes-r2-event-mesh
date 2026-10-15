#!/usr/bin/env bash
# ==============================================================================
# Instalador de Add-ons: Istio + Knative Serving/Eventing + KEDA
# 100% Cloud-Agnostic: Soporta K3s (Local) y Azure AKS (Cloud)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar versiones fijadas desde versions.env si existe
if [[ -f "$SCRIPT_DIR/versions.env" ]]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/versions.env"
fi

ISTIO_VERSION="${ISTIO_VERSION:-1.24.2}"
KNATIVE_VERSION="${KNATIVE_VERSION:-v1.16.0}"
# Normalizar tag de Knative (v1.16.0)
KNATIVE_TAG="${KNATIVE_VERSION#knative-}"
[[ "$KNATIVE_TAG" != v* ]] && KNATIVE_TAG="v$KNATIVE_TAG"
KEDA_VERSION="${KEDA_VERSION:-2.16.0}"

TARGET="local"
PUBLIC_IP=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target|-t)
      TARGET="$2"
      shift 2
      ;;
    --public-ip|-ip)
      PUBLIC_IP="$2"
      shift 2
      ;;
    local|azure|custom)
      TARGET="$1"
      shift 1
      ;;
    *)
      if [[ -z "$PUBLIC_IP" && "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        PUBLIC_IP="$1"
      fi
      shift 1
      ;;
  esac
done

echo "=========================================================="
echo "  Instalador de Add-ons: Istio + Knative + KEDA           "
echo "  Target: $TARGET                                         "
echo "  Versiones: Istio $ISTIO_VERSION | Knative $KNATIVE_TAG | KEDA $KEDA_VERSION"
echo "=========================================================="

# 1. Verificar conectividad con Kubernetes
kubectl cluster-info

# 2. Configurar archivo de valores de Istio y dominio Knative
ISTIO_VALUES="$SCRIPT_DIR/istio/values.yaml"
if [[ "$TARGET" == "azure" ]]; then
  ISTIO_VALUES="$SCRIPT_DIR/istio/aks-values.yaml"
  echo "  -> Usando configuración de Azure LoadBalancer para Istio Ingress."
else
  echo "  -> Usando configuración Local/K3s para Istio Ingress."
fi

if [[ -z "$PUBLIC_IP" ]]; then
  if [[ "$TARGET" == "local" ]]; then
    PUBLIC_IP="127.0.0.1"
  else
    PUBLIC_IP="azure.cloud"
  fi
fi

if [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  DOMAIN="$PUBLIC_IP.sslip.io"
else
  DOMAIN="example.com"
fi
echo "  -> Dominio configurado para Knative: $DOMAIN"

# 3. Istio
echo ""
echo "[1/4] Instalando Istio ($ISTIO_VERSION)..."
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo update istio
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --version "$ISTIO_VERSION"
helm upgrade --install istiod istio/istiod -n istio-system --version "$ISTIO_VERSION" --wait
helm upgrade --install istio-ingress istio/gateway -n istio-system -f "$ISTIO_VALUES" --version "$ISTIO_VERSION" --wait

# 4. Knative Serving + net-istio
echo ""
echo "[2/4] Instalando Knative Serving ($KNATIVE_TAG)..."
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-$KNATIVE_TAG/serving-crds.yaml"
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-$KNATIVE_TAG/serving-core.yaml"
kubectl apply -f "https://github.com/knative-extensions/net-istio/releases/download/knative-$KNATIVE_TAG/net-istio.yaml"
kubectl apply -f "$SCRIPT_DIR/knative/serving-config.yaml"
kubectl patch configmap/config-domain --namespace knative-serving --type merge --patch "{\"data\":{\"$DOMAIN\":\"\"}}"

# 5. Knative Eventing
echo ""
echo "[3/4] Instalando Knative Eventing ($KNATIVE_TAG)..."
kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$KNATIVE_TAG/eventing-crds.yaml"
kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$KNATIVE_TAG/eventing-core.yaml"
kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$KNATIVE_TAG/in-memory-channel.yaml"
kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$KNATIVE_TAG/mt-channel-broker.yaml"
kubectl apply -f "$SCRIPT_DIR/knative/eventing-broker.yaml"

# 6. KEDA
echo ""
echo "[4/4] Instalando KEDA ($KEDA_VERSION)..."
helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
helm repo update kedacore
helm upgrade --install keda kedacore/keda -n keda --create-namespace -f "$SCRIPT_DIR/keda/values.yaml" --version "$KEDA_VERSION" --wait

echo ""
echo "=== Verificando estado de componentes ==="
kubectl get pods -n istio-system
kubectl get pods -n knative-serving
kubectl get pods -n knative-eventing
kubectl get pods -n keda

echo ""
echo "=========================================================="
echo "  ¡Plataforma instalada exitosamente en $TARGET!          "
echo "=========================================================="
