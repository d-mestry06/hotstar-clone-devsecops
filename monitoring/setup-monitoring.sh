#!/bin/bash
# =============================================================================
# setup-monitoring.sh
# Installs Prometheus + Grafana on EKS using kube-prometheus-stack Helm chart
# Run from Jenkins EC2 after EKS is ready
# =============================================================================
set -euo pipefail

CLUSTER_NAME="hotstar-clone-devsecops-eks"
REGION="ap-south-1"
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
CHART_VERSION="58.3.0"   # kube-prometheus-stack

echo "════════════════════════════════════════════════════════"
echo "  Setting up Prometheus + Grafana on EKS"
echo "════════════════════════════════════════════════════════"

# ── 1. Connect to EKS ────────────────────────────────────────────────────────
echo "▶ Connecting to EKS..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# ── 2. Install Helm if not present ───────────────────────────────────────────
if ! command -v helm &> /dev/null; then
  echo "▶ Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm version

# ── 3. Add Prometheus Helm repo ──────────────────────────────────────────────
echo "▶ Adding Prometheus Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ── 4. Create monitoring namespace ───────────────────────────────────────────
echo "▶ Creating monitoring namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# ── 5. Install kube-prometheus-stack ─────────────────────────────────────────
echo "▶ Installing kube-prometheus-stack..."
helm upgrade --install $RELEASE_NAME \
  prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE \
  --version $CHART_VERSION \
  --values monitoring/prometheus-values.yaml \
  --wait \
  --timeout 10m

# ── 6. Apply custom alert rules & ServiceMonitor ────────────────────────────
echo "▶ Applying custom alert rules and ServiceMonitor..."
kubectl apply -f monitoring/alert-rules.yaml
kubectl apply -f monitoring/servicemonitor.yaml

# ── 7. Wait for pods ─────────────────────────────────────────────────────────
echo "▶ Waiting for monitoring pods..."
kubectl rollout status deployment/prometheus-grafana -n $NAMESPACE --timeout=300s
kubectl rollout status deployment/prometheus-kube-state-metrics -n $NAMESPACE --timeout=300s

# ── 8. Get Grafana URL ───────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  Monitoring setup complete!"
echo ""
echo "  Waiting for Grafana LoadBalancer URL..."
sleep 30

GRAFANA_URL=$(kubectl get svc prometheus-grafana -n $NAMESPACE \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo ""
echo "  Grafana URL    : http://${GRAFANA_URL}"
echo "  Username       : admin"
echo "  Password       : Hotstar@2024!"
echo ""
echo "  Pre-installed Dashboards:"
echo "  → Kubernetes Cluster Overview  (ID: 7249)"
echo "  → Kubernetes Pods              (ID: 6336)"
echo "  → Node Exporter Full           (ID: 1860)"
echo "  → NGINX                        (ID: 9614)"
echo "════════════════════════════════════════════════════════"
