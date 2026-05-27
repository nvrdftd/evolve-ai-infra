#!/usr/bin/env bash
# Bootstrap K8s components: NVIDIA device plugin, Kubeflow v1.9 (single-command
# install per https://github.com/kubeflow/manifests#install-with-a-single-command),
# and Kueue for GPU quota management.
#
# Prerequisites: kubectl, kustomize, helm, git configured against the target cluster.
# Run once after `terraform apply`. Safe to re-run (idempotent).
set -euo pipefail

KUBEFLOW_VERSION="v1.9.1"
KUEUE_VERSION="v0.10.1"
MANIFESTS_DIR=$(mktemp -d)
trap 'rm -rf "${MANIFESTS_DIR}"' EXIT

# ---------------------------------------------------------------------------
# 1. NVIDIA device plugin
#    The AL2023_x86_64_NVIDIA AMI includes drivers + container toolkit, but
#    the device plugin DaemonSet (which registers nvidia.com/gpu as a K8s
#    schedulable resource) must be deployed separately.
#    https://github.com/NVIDIA/k8s-device-plugin
# ---------------------------------------------------------------------------
echo "==> Installing NVIDIA device plugin..."
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update nvdp
helm upgrade --install nvdp nvdp/nvidia-device-plugin \
  --version 0.17.0 \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set tolerations[0].key=nvidia.com/gpu \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule

# ---------------------------------------------------------------------------
# 2. Kubeflow v1.9 — single-command install
#    The `example` kustomization bundles all components: cert-manager, Istio,
#    KServe v0.13 (LLMInferenceService + vLLM), Knative Serving, Pipelines,
#    Training Operator, Notebooks, Central Dashboard, Dex, and Profiles.
#    The retry loop handles CRD propagation delays between apply waves.
# ---------------------------------------------------------------------------
echo "==> Cloning Kubeflow manifests ${KUBEFLOW_VERSION}..."
git clone --depth 1 --branch "${KUBEFLOW_VERSION}" \
  https://github.com/kubeflow/manifests.git "${MANIFESTS_DIR}"
cd "${MANIFESTS_DIR}"

echo "==> Installing Kubeflow (single-command, may take 15-20 min)..."
while ! kustomize build example | kubectl apply -f -; do
  echo "Retrying to apply resources..."; sleep 20
done

# ---------------------------------------------------------------------------
# 3. Kueue
#    GPU quota management — works alongside Kubeflow Training Operator and
#    KServe for admission control of GPU workloads.
# ---------------------------------------------------------------------------
echo "==> Installing Kueue ${KUEUE_VERSION}..."
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl wait --for=condition=Available deployment/kueue-controller-manager \
  -n kueue-system --timeout=120s

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  kubectl apply -f infra/k8s/namespace-llm.yaml"
echo "  kubectl apply -f infra/k8s/hf-secret.yaml"
echo "  kubectl apply -f infra/k8s/hf-storage.yaml"
echo "  kubectl apply -f infra/k8s/kueue/"
echo "  kubectl apply -f infra/k8s/qwen2.5-7b-vllm.yaml"
echo ""
echo "Dashboard: kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
echo "           http://localhost:8080  |  user@example.com / 12341234"
