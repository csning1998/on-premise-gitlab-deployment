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
readonly PROD_VAULT_TOKEN_FILE="${ANSIBLE_DIR}/fetched/vault/vault_init_output.json"

vault_context_handler() {
  local target="$1"

  unset VAULT_ADDR VAULT_TOKEN VAULT_CACERT

  if [[ "$target" == "prod" ]]; then
		log_print "INFO" "[Vault Context] Switching to PRODUCTION (Layer 20+)..."

    export VAULT_ADDR="$PROD_VAULT_ADDR"
    export VAULT_CACERT="$PROD_CA_CERT"

    # Read the token
    if [[ -f "$PROD_VAULT_TOKEN_FILE" ]]; then
      local prod_token
      prod_token=$(jq -r '.root_token // empty' "$PROD_VAULT_TOKEN_FILE" 2>/dev/null)
      
      if [[ -n "$prod_token" ]]; then
				export VAULT_TOKEN="$prod_token"
				log_print "INFO" "    - Token loaded from file."
      else
				log_print "WARN" "Token file exists but could not parse root_token."
      fi
    else
      log_print "WARN" "Prod Vault Token file not found at $PROD_VAULT_TOKEN_FILE"
      log_print "WARN" "(Expected if Prod Vault is not yet initialized)"
    fi

  else
    log_print "INFO" "[Vault Context] Switching to DEVELOPMENT (Layer <20 / Packer)..."
    
    export VAULT_ADDR="$DEV_VAULT_ADDR"
    export VAULT_TOKEN="${DEV_VAULT_TOKEN}"

    # Choose the CA based on the environment strategy.
    if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
        export VAULT_CACERT="${DEV_VAULT_CACERT_PODMAN}"
    else
        export VAULT_CACERT="${DEV_VAULT_CACERT}"
    fi
  fi

	log_print "INFO" "    - VAULT_ADDR: $VAULT_ADDR"
}

# Status Reporting
vault_status_reporter() {

  log_divider

  # Check Development Vault on Host
	if curl -s --connect-timeout 0.5 --cacert "${DEV_CA}" "${DEV_VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
    local dev_status_json
    dev_status_json=$(vault status -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json 2>/dev/null || true)

    if [[ -n "$dev_status_json" ]]; then
      local sealed
      sealed=$(echo "$dev_status_json" | jq .sealed)
      if [[ "$sealed" == "true" ]]; then
				log_print "WARN" "Development Vault (Local): Running (Sealed)"
      else
				log_print "OK" "Development Vault (Local): Running (Unsealed)"
      fi
    else
			log_print "WARN" "Development Vault (Local): Running (Status Query Failed)"
    fi
  else
    log_print "ERROR" "Development Vault (Local): Stopped or Unreachable"
  fi

  # Check Production Vault on Production Guest VM
	if [[ ! -f "$PROD_CA_CERT" ]]; then
    log_print "WARN" "Production Vault (Layer10): Unknown (CA Cert missing)"
  elif curl -s --connect-timeout 1 --cacert "${PROD_CA_CERT}" "${PROD_VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
		local prod_status_json
    prod_status_json=$(vault status -address="${PROD_VAULT_ADDR}" -ca-cert="${PROD_CA_CERT}" -format=json 2>/dev/null || true)
	
		if [[ -n "$prod_status_json" ]]; then
				log_print "OK" "Production Vault (Layer10): Running (Unsealed)"
		fi
	else	# including connection refused, SSL error, Unsealed, EOF, timeout...
		log_print "ERROR" "Production Vault (Layer10): Stopped or Unsealed or Unreachable"
	fi
  log_divider
}

# Function: Generate TLS Certs for Development Vault (Host)
# Function: Generate TLS Certs for Development Vault (Host)
vault_dev_tls_generator() {

  log_print "STEP" "[Development Vault] Generating CA Root files for TLS..."
  log_print "WARN" "#############################################################################"
  log_print "WARN" "### Proceeding will DESTROY ALL existing files in vault/tls.              ###"
  log_print "WARN" "#############################################################################"
  
  log_print "INPUT" "Type 'yes' to confirm: "
  read -r confirmation
  
  if [[ "$confirmation" != "yes" ]]; then
    log_print "INFO" "Cancelled."
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
  
  log_print "OK" "Dev Vault TLS Certificates generated in ${DEV_TLS_DIR}"
}

# Function: Ensure KV Engine is enabled (Dev Vault)
vault_dev_engine_enforcer() {
  log_print "TASK" "[Development Vault] Ensuring KV secrets engine is enabled at 'secret/'..."
  
  if [ ! -f "$DEV_ROOT_TOKEN_FILE" ]; then
		log_print "ERROR" "Root token not found. Cannot configure engine."
		return 1
  fi
  
  local token
  token=$(cat "$DEV_ROOT_TOKEN_FILE")
  
  if ! VAULT_ADDR="$DEV_VAULT_ADDR" VAULT_TOKEN="$token" vault secrets list -ca-cert="${DEV_CA}" -format=json | jq -e '."secret/"' > /dev/null; then
    log_print "TASK" "'secret/' path not found, enabling kv-v2..."
    VAULT_ADDR="$DEV_VAULT_ADDR" VAULT_TOKEN="$token" vault secrets enable -ca-cert="${DEV_CA}" -path=secret kv-v2
  else
    log_print "INFO" "kv-v2 secrets engine is already enabled."
  fi
}

# Function: Initialize, Unseal, Login, and Configure Dev Vault
vault_dev_init_handler() {
  log_print "STEP" "[Dev Vault] Initializing Local Podman Vault..."

  if [[ -f "$DEV_INIT_FILE" ]]; then
		log_print "WARN" "Init file exists. Skipping to prevent data loss."
		return 1
  fi

  mkdir -p "$DEV_KEYS_DIR"

  log_print "TASK" "Initializing..."
	if ! vault operator init -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json > "$DEV_INIT_FILE"; then
    log_print "FATAL" "Initialization failed. Is Dev Vault running?"
    return 1
  fi

  # Extract Keys
  jq -r .unseal_keys_b64[] "$DEV_INIT_FILE" > "$DEV_UNSEAL_KEY_FILE"
  jq -r .root_token "$DEV_INIT_FILE" > "$DEV_ROOT_TOKEN_FILE"
  chmod 600 "$DEV_KEYS_DIR"/*

	log_print "TASK" "Automatically updating DEV_VAULT_TOKEN in .env file..."
  local new_token
  new_token=$(cat "$DEV_ROOT_TOKEN_FILE")
  env_var_mutator "DEV_VAULT_TOKEN" "${new_token}"

	log_print "INFO" "Keys saved to ${DEV_KEYS_DIR}"

  # Auto Unseal
  vault_dev_unseal_handler

	vault login -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_VAULT_CACERT}" "${new_token}"

  # Auto Configure Engine
  vault_dev_engine_enforcer

  log_print "OK" "Dev Vault is ready for use."
}

# Function: Unseal Dev Vault
vault_dev_unseal_handler() {
  log_print "STEP" "[Dev Vault] Unsealing..."
  
  if [ ! -f "$DEV_UNSEAL_KEY_FILE" ]; then
    log_print "ERROR" "Unseal keys not found. Run '[DEV] Initialize' first."
    return 1
  fi

  local status_json
	status_json=$(vault status -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" -format=json 2>/dev/null || true)  
  if [[ $(echo "$status_json" | jq .sealed 2>/dev/null) == "false" ]]; then
    log_print "INFO" "Development Vault is already unsealed."
    return 0
  fi

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    vault operator unseal -address="${DEV_VAULT_ADDR}" -ca-cert="${DEV_CA}" "$key" > /dev/null
  done < "$DEV_UNSEAL_KEY_FILE"

  log_print "OK" "Dev Vault Unsealed."
  
  # Export for current session
  if [ -f "$DEV_ROOT_TOKEN_FILE" ]; then
		DEV_VAULT_TOKEN=$(cat "$DEV_ROOT_TOKEN_FILE")
		export DEV_VAULT_TOKEN
		export VAULT_ADDR="${DEV_VAULT_ADDR}"
		export VAULT_CACERT="${DEV_CA}"
		log_print "INFO" "Exported DEV_VAULT_TOKEN and set VAULT_ADDR to Dev Vault for this session."
  fi
}

# Function: Trigger Ansible to Unseal Prod Vault
vault_prod_unseal_trigger() {
  log_print "STEP" "[Production Vault] Triggering Ansible Playbook for Unseal..."
  
  local inventory_file="${ANSIBLE_DIR}/inventory-10-vault-core.yaml"

  if [[ ! -f "$inventory_file" ]]; then
		log_print "ERROR" "Inventory file not found."
		return 1
  fi
  
  ansible-playbook -i "$inventory_file" "${ANSIBLE_DIR}/playbooks/90-operation-vault-unseal.yaml"
  log_print "OK" "[Prod Vault] Unseal Playbook execution completed."

	sleep 2
}
