helm uninstall kserve-runtime-configs -n kserve
helm uninstall kserve-llmisvc-resources -n kserve
helm uninstall kserve-llmisvc-crd -n kserve
curl -fsSL https://github.com/kserve/kserve/releases/download/v0.18.0/llmisvc-dependency-install.sh | bash -s -- --uninstall