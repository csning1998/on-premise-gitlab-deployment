# Troubleshooting

## TLS Certificates

If the following error occurs while running `terraform apply`:

> tls: failed to find any PEM data in certificate input

This typically indicates that the certificate has expired or that the internal certificate has been rotated and no longer aligns with the Terraform state. In this scenario, you must obtain a new certificate without initializing the `postgresql` provider.

1. **Run an isolated apply for the certificate resource.**

    This forces Terraform to prioritize Vault resources while bypassing the unreachable Postgres provider.

    ```bash
    terraform apply -auto-approve \
        -target="vault_pki_secret_backend_cert.gitlab_db_client" \
        -replace="vault_pki_secret_backend_cert.gitlab_db_client"
    ```

2. **Verify that the certificate has been updated.**

    After the command completes, verify that the `certificate` attribute in the state reflects the current timestamp. You can check the certificate's expiration dates using the following command:

    ```bash
    python3 -c 'import json, subprocess; state = json.load(open("terraform.tfstate")); cert = [r["instances"][0]["attributes"]["certificate"] for r in state["resources"] if r["name"] == "gitlab_db_client"][0]; subprocess.run(["openssl", "x509", "-noout", "-dates"], input=cert.encode())'
    ```

3. **Perform a full Apply.**

    Once the state contains valid PEM data, the provider will initialize successfully, allowing you to proceed with a standard apply:

    ```bash
    terraform apply -auto-approve
    ```
