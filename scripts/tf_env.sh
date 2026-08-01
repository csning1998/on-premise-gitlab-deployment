#!/bin/bash

# Exports the GitLab HTTP backend credentials required by every layer's
# `backend "http"` block. Must be sourced, not executed, so the exports
# persist in the calling shell: `source scripts/tf_env.sh`.
_TF_ENV_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

export TF_HTTP_USERNAME
export TF_HTTP_PASSWORD
TF_HTTP_USERNAME=$(python3 -c "import json; print(json.load(open('${_TF_ENV_REPO_ROOT}/terraform/backend-state.json'))['username'])")
TF_HTTP_PASSWORD=$(python3 -c "import json; print(json.load(open('${_TF_ENV_REPO_ROOT}/terraform/backend-state.json'))['token'])")

unset _TF_ENV_REPO_ROOT
echo "TF_HTTP_USERNAME and TF_HTTP_PASSWORD exported for this shell."
