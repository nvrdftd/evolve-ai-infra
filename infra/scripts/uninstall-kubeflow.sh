#!/usr/bin/env bash
# Uninstall all K8s components installed by install-kubeflow.sh.
# Run before `terraform destroy` to cleanly remove cluster workloads.
set -euo pipefail

KUBEFLOW_VERSION="v1.9.1"
MANIFESTS_DIR=$(mktemp -d)
trap 'rm -rf "${MANIFESTS_DIR}"' EXIT

# ---------------------------------------------------------------------------
# 1. Model serving resources
# ---------------------------------------------------------------------------
echo "==> Removing model serving resources..."
kubectl delete -f infra/k8s/qwen2.5-7b-vllm.yaml --ignore-not-found
kubectl delete -f infra/k8s/hf-storage.yaml --ignore-not-found
kubectl delete -f infra/k8s/hf-secret.yaml --ignore-not-found
kubectl delete -f infra/k8s/namespace-llm.yaml --ignore-not-found

# ---------------------------------------------------------------------------
# 2. Kubeflow
# ---------------------------------------------------------------------------
echo "==> Removing Kubeflow ${KUBEFLOW_VERSION}..."
git clone --depth 1 --branch "${KUBEFLOW_VERSION}" \
  https://github.com/kubeflow/manifests.git "${MANIFESTS_DIR}"
cd "${MANIFESTS_DIR}"
kustomize build example | kubectl delete -f - --ignore-not-found
cd -

# ---------------------------------------------------------------------------
# 3. DCGM Exporter
# ---------------------------------------------------------------------------
echo "==> Removing DCGM Exporter..."
helm uninstall dcgm-exporter -n monitoring --ignore-not-found

# ---------------------------------------------------------------------------
# 4. kube-prometheus-stack
# ---------------------------------------------------------------------------
echo "==> Removing kube-prometheus-stack..."
helm uninstall kube-prometheus-stack -n monitoring --ignore-not-found
# CRDs are not removed by helm uninstall — delete manually
kubectl delete crd \
  alertmanagerconfigs.monitoring.coreos.com \
  alertmanagers.monitoring.coreos.com \
  podmonitors.monitoring.coreos.com \
  probes.monitoring.coreos.com \
  prometheusagents.monitoring.coreos.com \
  prometheuses.monitoring.coreos.com \
  prometheusrules.monitoring.coreos.com \
  scrapeconfigs.monitoring.coreos.com \
  servicemonitors.monitoring.coreos.com \
  thanosrulers.monitoring.coreos.com \
  --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

# ---------------------------------------------------------------------------
# 5. NVIDIA device plugin
# ---------------------------------------------------------------------------
echo "==> Removing NVIDIA device plugin..."
helm uninstall nvdp -n nvidia-device-plugin --ignore-not-found
kubectl delete namespace nvidia-device-plugin --ignore-not-found

echo ""
echo "Uninstall complete. Safe to run: terraform destroy"
