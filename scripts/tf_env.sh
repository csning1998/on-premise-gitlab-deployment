#!/bin/bash

# Exports the Vault Proxy environment and the GitLab HTTP backend credentials of consumer-opgitlab.
# The exports persist in the calling shell only when the script is sourced: `source scripts/tf_env.sh`.
if ! command -v vault-proxy-env >/dev/null; then
    echo "vault-proxy-env is missing, run the first menu item of ./governance in parent-group-governance" >&2
    return 1
fi

_tf_env_proxy=$(vault-proxy-env consumer-opgitlab) || { unset _tf_env_proxy; return 1; }
eval "${_tf_env_proxy}"
unset _tf_env_proxy
echo "Vault Proxy environment and TF_HTTP_* of consumer-opgitlab exported for this shell."
