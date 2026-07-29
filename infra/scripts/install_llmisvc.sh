#!/usr/bin/env bash

LLMISVC_CHART_VERSION=v0.18.0

# Login to GitHub Package Registry
gh auth token | helm registry login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Install CRDs
# Using OCI registry (recommended)
helm upgrade -i kserve-llmisvc-crd oci://ghcr.io/kserve/charts/kserve-llmisvc-crd \
  --version $LLMISVC_CHART_VERSION \
  --namespace kserve \
  --create-namespace

# Install LLMInferenceService Resources
# Using OCI registry (recommended)
helm upgrade -i kserve-llmisvc-resources oci://ghcr.io/kserve/charts/kserve-llmisvc-resources \
  --version $LLMISVC_CHART_VERSION \
  --create-namespace \
  --namespace kserve \
  --take-ownership \
  --wait

# Install preconfigured manifests
helm upgrade -i kserve-runtime-configs oci://ghcr.io/kserve/charts/kserve-runtime-configs \
  --version $LLMISVC_CHART_VERSION \
  --namespace kserve \
  --set kserve.llmisvcConfigs.enabled=true