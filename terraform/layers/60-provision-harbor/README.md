# Layer 60: Production Harbor Frontend

## Problem Diagnosis: Duplicate User Conflict (OIDC Identity Drift)

Refer to [40-provision-harbor-databases/README.md](../40-provision-harbor-databases/README.md) with the same title for more information.

For the production Harbor instance running on MicroK8s, the database is hosted externally on Patroni (`core-harbor-postgres-node-00`).

1. Retrieve the PostgreSQL superuser password from the Patroni configuration on the Patroni node:

    ```bash
    sudo grep -A 5 'superuser:' /etc/patroni.yml
    ```

2. Log in using the TCP interface and perform the same deletion:

    ```bash
    # Connect to Patroni VIP/Host and execute cleanup
    PGPASSWORD='<superuser_password>' psql -h 172.16.132.200 -U postgres -d registry -c "
        DELETE FROM oidc_user WHERE user_id = <user_id>;
        DELETE FROM harbor_user WHERE user_id = <user_id>;
    "
    ```

3. Re-login via OIDC on Harbor UI.
