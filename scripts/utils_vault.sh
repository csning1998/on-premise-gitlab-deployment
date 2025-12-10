#!/bin/bash

# Development Vault Variables 

# Prior to read the setting from .env, if not found, use default value
readonly DEV_VAULT_ADDR="${DEV_VAULT_ADDR:-https://127.0.0.1:8200}"

# Determine the CA path based on environment strategy
if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
	readonly DEV_CA="${DEV_VAULT_CACERT_PODMAN:-/app/vault/tls/ca.pem}"
else
	readonly DEV_CA="${DEV_VAULT_CACERT:-${SCRIPT_DIR}/vault/tls/ca.pem}"
fi
readonly DEV_KEYS_DIR="${SCRIPT_DIR}/vault/keys"
readonly DEV_TLS_DIR="${SCRIPT_DIR}/vault/tls"
readonly DEV_INIT_FILE="${DEV_KEYS_DIR}/init-output.json"
readonly DEV_UNSEAL_KEY_FILE="${DEV_KEYS_DIR}/unseal.key"
readonly DEV_ROOT_TOKEN_FILE="${DEV_KEYS_DIR}/root-token.txt"

# Production Vault Variables
readonly PROD_VAULT_ADDR="https://172.16.136.250:443"
readonly PROD_CA_CERT="${TERRAFORM_DIR}/layers/10-vault-core/tls/vault-ca.crt"

# Status Reporting
vault_status_reporter() {
  local red='\033[0;31m'
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local reset='\033[0m'

  echo "--------------------------------------------------"

  # Check Development Vault on Host
	if curl -s --connect-timeout 0.5 --cacert "${DEV_CA}" "${DEV_VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
    local dev_status_json
    dev_status_json=$(vault status -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json 2>/dev/null || true)

    if [[ -n "$dev_status_json" ]]; then
      local sealed
      sealed=$(echo "$dev_status_json" | jq .sealed)
      if [[ "$sealed" == "true" ]]; then
        echo -e "Development Vault (Local): ${yellow}Running (Sealed)${reset}"
      else
        echo -e "Development Vault (Local): ${green}Running (Unsealed)${reset}"
      fi
    else
      echo -e "Development Vault (Local): ${yellow}Running (Status Query Failed)${reset}"
    fi
  else
    echo -e "Development Vault (Local): ${red}Stopped or Unreachable${reset}"
  fi

  # Check Production Vault on Production Guest VM
  if [[ ! -f "$PROD_CA_CERT" ]]; then
    echo -e "Production Vault (Layer10): ${yellow}Unknown (CA Cert missing)${reset}"
  elif curl -s --connect-timeout 1 --cacert "${PROD_CA_CERT}" "${PROD_VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
		local prod_status_json
    prod_status_json=$(vault status -address="${PROD_VAULT_ADDR}" -ca-cert="${PROD_CA_CERT}" -format=json 2>/dev/null || true)
	
		if [[ -n "$prod_status_json" ]]; then
				echo -e "Production Vault (Layer10): ${green}Running (Unsealed)${reset}"
		fi
	else	# including connection refused, SSL error, Unsealed, EOF, timeout...
		echo -e "Production Vault (Layer10): ${red}Stopped or Unsealed or Unreachable${reset}"
	fi
  echo "--------------------------------------------------"
}

# Function: Generate TLS Certs for Development Vault (Host)
vault_dev_tls_generator() {

  echo ">>> [Development Vault] Generating CA Root files for TLS..."
  echo "#############################################################################"
  echo "### Proceeding will DESTROY ALL existing files in vault/tls.              ###"
  echo "#############################################################################"
  read -r -p "### Type 'yes' to confirm: " confirmation
  if [[ "$confirmation" != "yes" ]]; then
    echo "#### Cancelled."
    return 1
  fi

  rm -rf "${DEV_TLS_DIR}"
  mkdir -p "${DEV_TLS_DIR}"

  # Generate CA and Certs
  openssl genrsa -out "${DEV_TLS_DIR}/ca-key.pem" 2048
  openssl req -new -x509 -days 365 -key "${DEV_TLS_DIR}/ca-key.pem" -sha256 -out "${DEV_TLS_DIR}/ca.pem" -subj "/CN=DevVaultCA"

  openssl genrsa -out "${DEV_TLS_DIR}/vault-key.pem" 2048
  openssl req -subj "/CN=localhost" -sha256 -new -key "${DEV_TLS_DIR}/vault-key.pem" -out "${DEV_TLS_DIR}/vault.csr"

  echo "subjectAltName = DNS:localhost,IP:127.0.0.1" > "${DEV_TLS_DIR}/extfile.cnf"

  openssl x509 -req -days 365 -sha256 -in "${DEV_TLS_DIR}/vault.csr" \
    -CA "${DEV_TLS_DIR}/ca.pem" -CAkey "${DEV_TLS_DIR}/ca-key.pem" \
    -CAcreateserial -out "${DEV_TLS_DIR}/vault.pem" \
    -extfile "${DEV_TLS_DIR}/extfile.cnf"

  rm -f "${DEV_TLS_DIR}/vault.csr" "${DEV_TLS_DIR}/extfile.cnf"
  chmod 600 "${DEV_TLS_DIR}/"*key.pem
  chmod 644 "${DEV_TLS_DIR}/"*.pem
  
  echo "#### Dev Vault TLS Certificates generated in ${DEV_TLS_DIR}"
}

# Function: Ensure KV Engine is enabled (Dev Vault)
vault_dev_engine_enforcer() {
  echo ">>> [Development Vault] Ensuring KV secrets engine is enabled at 'secret/'..."
  
  if [ ! -f "$DEV_ROOT_TOKEN_FILE" ]; then
      echo "#### ERROR: Root token not found. Cannot configure engine."
      return 1
  fi
  
  local token
  token=$(cat "$DEV_ROOT_TOKEN_FILE")
  
  if ! VAULT_ADDR="$DEV_VAULT_ADDR" VAULT_TOKEN="$token" vault secrets list -ca-cert="${DEV_CA}" -format=json | jq -e '."secret/"' > /dev/null; then
    echo "#### 'secret/' path not found, enabling kv-v2..."
    VAULT_ADDR="$DEV_VAULT_ADDR" VAULT_TOKEN="$token" vault secrets enable -ca-cert="${DEV_CA}" -path=secret kv-v2
  else
    echo "#### kv-v2 secrets engine is already enabled."
  fi
}

# Function: Initialize, Unseal, Login, and Configure Dev Vault
vault_dev_init_handler() {
  echo ">>> [Dev Vault] Initializing Local Podman Vault..."

  if [[ -f "$DEV_INIT_FILE" ]]; then
		echo "#### WARNING: Init file exists. Skipping to prevent data loss."
		return 1
  fi

  mkdir -p "$DEV_KEYS_DIR"

  echo "#### Initializing..."
	if ! vault operator init -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json > "$DEV_INIT_FILE"; then
    echo "#### ERROR: Initialization failed. Is Dev Vault running?"
    return 1
  fi

  # Extract Keys
  jq -r .unseal_keys_b64[] "$DEV_INIT_FILE" > "$DEV_UNSEAL_KEY_FILE"
  jq -r .root_token "$DEV_INIT_FILE" > "$DEV_ROOT_TOKEN_FILE"
  chmod 600 "$DEV_KEYS_DIR"/*

	echo "#### Automatically updating DEV_VAULT_TOKEN in .env file..."
  local new_token
  new_token=$(cat "$DEV_ROOT_TOKEN_FILE")
  env_var_mutator "DEV_VAULT_TOKEN" "${new_token}"

  echo "#### Keys saved to ${DEV_KEYS_DIR}"

  # Auto Unseal
  vault_dev_seal_handler

	vault login -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_VAULT_CACERT}" "${new_token}"

  # Auto Configure Engine
  vault_dev_engine_enforcer

  echo "#### Dev Vault is ready for use."
}

# Function: Unseal Dev Vault
vault_dev_seal_handler() {
  echo ">>> [Dev Vault] Unsealing..."
  
  if [ ! -f "$DEV_UNSEAL_KEY_FILE" ]; then
    echo "#### ERROR: Unseal keys not found. Run '[DEV] Initialize' first."
    return 1
  fi

  local status_json
	status_json=$(vault status -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json 2>/dev/null || true)  
  if [[ $(echo "$status_json" | jq .sealed 2>/dev/null) == "false" ]]; then
    echo "#### Development Vault is already unsealed."
    return 0
  fi

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    vault operator unseal -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" "$key" > /dev/null
  done < "$DEV_UNSEAL_KEY_FILE"

  echo "#### Dev Vault Unsealed."
  
  # Export for current session
  if [ -f "$DEV_ROOT_TOKEN_FILE" ]; then
		export DEV_VAULT_TOKEN=$(cat "$DEV_ROOT_TOKEN_FILE")
		export VAULT_ADDR="${DEV_VAULT_ADDR}"
		export VAULT_CACERT="${DEV_CA}"
		echo "#### INFO: Exported DEV_VAULT_TOKEN and set VAULT_ADDR to Dev Vault for this session."
  fi
}

# Function: Trigger Ansible to Unseal Prod Vault
vault_prod_unseal_trigger() {
  echo ">>> [Production Vault] Triggering Ansible Playbook for Unseal..."
  
  local inventory_file="${ANSIBLE_DIR}/inventory-vault-cluster.yaml"
  
  if [[ ! -f "$inventory_file" ]]; then
		inventory_file="${TERRAFORM_DIR}/layers/10-vault-core/inventory-vault-cluster.yaml"
  fi

  if [[ ! -f "$inventory_file" ]]; then
		echo "#### ERROR: Inventory file not found."
		return 1
  fi
  
  ansible-playbook -i "$inventory_file" "${ANSIBLE_DIR}/playbooks/90-operation-vault-unseal.yaml"
  echo ">>> [Prod Vault] Unseal Playbook execution completed."

	sleep 2
}
