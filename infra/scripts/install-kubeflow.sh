#!/usr/bin/env bash
# Bootstrap K8s components: cert-manager, Istio,
# Kubeflow v1.9 (includes KServe v0.13 + vLLM support), and Kueue.
#
# Prerequisites (must be satisfied before running):
#   - kubectl, kustomize, istioctl, git configured against the target cluster
#
# Run once after `terraform apply`. Safe to re-run (idempotent).
set -euo pipefail

KUBEFLOW_VERSION="v1.9.1"
KUEUE_VERSION="v0.10.1"
MANIFESTS_DIR=$(mktemp -d)
trap 'rm -rf "${MANIFESTS_DIR}"' EXIT

# ---------------------------------------------------------------------------
# 1. NVIDIA device plugin
#    The AL2023_x86_64_NVIDIA AMI includes drivers + container toolkit, but the
#    device plugin DaemonSet (which registers nvidia.com/gpu as a K8s resource)
#    must still be deployed separately.
# ---------------------------------------------------------------------------
echo "==> Installing NVIDIA device plugin..."
kubectl apply -f \
  https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml

# ---------------------------------------------------------------------------
# 3. cert-manager
#    Required by Kubeflow webhooks. Installing standalone first avoids a race
#    with Kubeflow's own cert-manager kustomize step.
# ---------------------------------------------------------------------------
echo "==> Installing cert-manager..."
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml
kubectl wait --for=condition=Available deployment/cert-manager-webhook \
  -n cert-manager --timeout=180s

# ---------------------------------------------------------------------------
# 4. Istio (minimal profile)
#    Required for Kubeflow multi-tenancy, traffic routing, and auth integration.
# ---------------------------------------------------------------------------
echo "==> Installing Istio (minimal profile)..."
istioctl install -y --set profile=minimal
kubectl wait --for=condition=Available deployment/istiod \
  -n istio-system --timeout=180s

# ---------------------------------------------------------------------------
# 5. Kubeflow v1.9
#    Includes: KServe v0.13 (LLMInferenceService + vLLM), Knative Serving,
#    Pipelines, Training Operator, Notebooks, Central Dashboard, Dex, Profiles.
#    kserve.sh is NOT used — this install provides KServe.
# ---------------------------------------------------------------------------
echo "==> Cloning Kubeflow manifests ${KUBEFLOW_VERSION}..."
git clone --depth 1 --branch "${KUBEFLOW_VERSION}" \
  https://github.com/kubeflow/manifests.git "${MANIFESTS_DIR}"
cd "${MANIFESTS_DIR}"

apply_component() {
  local component="$1"
  echo "--> Applying ${component}"
  until kustomize build "${component}" | kubectl apply -f -; do
    echo "    Retrying ${component} in 10s..."; sleep 10
  done
}

echo "==> Installing Kubeflow components..."
apply_component "common/cert-manager/kubeflow-issuer/base"
apply_component "common/istio-1-22/istio-crds/base"
apply_component "common/istio-1-22/istio-install/overlays/oauth2-proxy"
apply_component "common/oidc-authservice/base"
apply_component "common/dex/overlays/istio"
apply_component "common/knative/knative-serving/overlays/gateways"
apply_component "contrib/kserve/kserve"
apply_component "contrib/kserve/models-web-app/overlays/kubeflow"
apply_component "common/kubeflow-namespace/base"
apply_component "common/kubeflow-roles/base"
apply_component "common/istio-1-22/kubeflow-istio-resources/base"
apply_component "apps/centraldashboard/upstream/overlays/kserve"
apply_component "apps/pipeline/upstream/env/platform-agnostic-multi-user"
apply_component "apps/training-operator/upstream/overlays/kubeflow"
apply_component "apps/jupyter/notebook-controller/upstream/overlays/kubeflow"
apply_component "apps/jupyter/jupyter-web-app/upstream/overlays/istio"
apply_component "apps/profiles/upstream/overlays/kubeflow"
apply_component "common/user-namespace/base"

# ---------------------------------------------------------------------------
# 6. Kueue
#    GPU quota management — works alongside Kubeflow Training Operator and KServe.
# ---------------------------------------------------------------------------
echo "==> Installing Kueue ${KUEUE_VERSION}..."
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl wait --for=condition=Available deployment/kueue-controller-manager \
  -n kueue-system --timeout=120s

echo ""
echo "Bootstrap complete (~15-20 min total)."
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
