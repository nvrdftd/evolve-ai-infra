#!/usr/bin/env bash
# Bootstrap K8s components: NVIDIA device plugin, Prometheus stack, DCGM Exporter,
# and Kubeflow v1.9 (single-command install per
# https://github.com/kubeflow/manifests#install-with-a-single-command).
# Kubeflow Training Operator v1.8 (bundled in v1.9) has native Kueue
# integration — no separate Kueue install required.
#
# Prerequisites: kubectl, kustomize, helm, git configured against the target cluster.
# Run once after `terraform apply`. Safe to re-run (idempotent).
set -euo pipefail

# Update kubeconfig for the current EKS cluster named evolve-ai-infra-dev" in the region eu-north-1
aws eks update-kubeconfig --name "evolve-ai-infra-dev" --region eu-north-1

KUBEFLOW_VERSION="26.03"
# MANIFESTS_DIR=$(mktemp -d)
# trap 'rm -rf "${MANIFESTS_DIR}"' EXIT

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
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace \
  -f infra/k8s/nvdp-values.yaml

# ---------------------------------------------------------------------------
# 2. Prometheus (kube-prometheus-stack)
#    Installs Prometheus, Grafana, Alertmanager, and the Prometheus Operator.
#    Must run before DCGM Exporter so the ServiceMonitor CRD is available.
# ---------------------------------------------------------------------------
echo "==> Installing kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
kubectl wait --for=condition=Available deployment/kube-prometheus-stack-grafana \
  -n monitoring --timeout=180s

# Get the application URL by running these commands:
# export POD_NAME=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=dcgm-exporter,app.kubernetes.io/instance=dcgm-exporter" -o jsonpath="{.items[0].metadata.name}")
# kubectl -n monitoring port-forward $POD_NAME 8080:9400 &
# echo "Visit http://127.0.0.1:8080/metrics to use your application"

# ---------------------------------------------------------------------------
# 3. DCGM Exporter
#    Exposes per-GPU metrics (utilization, memory, temperature, power) to
#    Prometheus on port 9400. Runs only on GPU nodes.
#    https://nvidia.github.io/dcgm-exporter/helm-charts
# ---------------------------------------------------------------------------
echo "==> Installing DCGM Exporter..."
helm repo add dcgm-exporter https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update dcgm-exporter
helm upgrade --install dcgm-exporter dcgm-exporter/dcgm-exporter \
  --namespace monitoring \
  --create-namespace \
  --set "tolerations[0].key=nvidia.com/gpu" \
  --set "tolerations[0].operator=Exists" \
  --set "tolerations[0].effect=NoSchedule" \
  --set "nodeSelector.workload=gpu"

# ---------------------------------------------------------------------------
# 4. Kubeflow v1.9 — single-command install
#    Bundles: cert-manager, Istio, KServe v0.13 (LLMInferenceService + vLLM),
#    Knative Serving, Pipelines, Training Operator v1.8, Notebooks,
#    Central Dashboard, Dex, and Profiles.
#    The retry loop handles CRD propagation delays between apply waves.
# ---------------------------------------------------------------------------
# echo "==> Cloning Kubeflow manifests ${KUBEFLOW_VERSION}..."
# git clone --depth 1 --branch "${KUBEFLOW_VERSION}" \
#   https://github.com/kubeflow/manifests.git "${MANIFESTS_DIR}"
# cd "${MANIFESTS_DIR}"

# echo "==> Installing Kubeflow (single-command, may take 15-20 min)..."
# # --server-side avoids the 262144-byte annotation limit hit by large CRDs (inferenceservices, jobsets, etc.)
# # --force-conflicts lets server-side apply win on field ownership conflicts from prior apply attempts
# while ! kustomize build example | kubectl apply --server-side --force-conflicts -f -; do
#   echo "Retrying to apply resources..."; sleep 20
# done

# Install dependencies for LLMIsvc mode
curl -fsSL https://github.com/kserve/kserve/releases/download/v0.18.0/llmisvc-dependency-install.sh | bash

# ---------------------------------------------------------------------------
# 5. KServe ingress gateway
#    Kubeflow 26.03 ships LLMInferenceService but does not create the Gateway
#    resource that llmisvc expects. The Kubeflow overlay moves KServe into the
#    kubeflow namespace, so the gateway belongs there too.
#    The inferenceservice-config ConfigMap must be patched to match: the default
#    kserveIngressGateway value points to "kserve/kserve-ingress-gateway" but
#    the kubeflow overlay never creates the kserve namespace.
# ---------------------------------------------------------------------------
# echo "==> Applying KServe ingress configs..."
# cd -
# kubectl apply -f infra/k8s/kserve-llm-configs.yaml

# Patch kserveIngressGateway to point at kubeflow namespace (where KServe lives).
# CURRENT_INGRESS=$(kubectl get configmap inferenceservice-config -n kubeflow \
#   -o jsonpath='{.data.ingress}')
# PATCHED_INGRESS=$(echo "${CURRENT_INGRESS}" | \
#   python3 -c "import sys,json; d=json.load(sys.stdin); d['kserveIngressGateway']='kubeflow/kserve-ingress-gateway'; print(json.dumps(d))")
# kubectl patch configmap inferenceservice-config -n kubeflow --type=merge \
#   -p "{\"data\":{\"ingress\":$(echo "${PATCHED_INGRESS}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")}}"

# kubectl rollout restart deployment/llmisvc-controller-manager -n kubeflow
# kubectl wait --for=condition=Available deployment/llmisvc-controller-manager \
#   -n kubeflow --timeout=60s

# echo ""
# echo "Bootstrap complete."
# echo ""
# echo "Next steps:"
# echo "  kubectl apply -f infra/k8s/namespace-llm.yaml"
# echo "  kubectl apply -f infra/k8s/hf-secret.yaml      # do NOT commit — contains token"
# echo "  kubectl apply -f infra/k8s/hf-storage.yaml     # do NOT commit — contains token ref"
# echo "  kubectl apply -f infra/k8s/qwen2.5-7b-vllm.yaml"
# echo ""
# echo "Dashboard: kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
# echo "           http://localhost:8080  |  user@example.com / 12341234"
