# Environment Setup

## A. Podman / Container Setup

For Podman-based setups, navigate to the project root directory after the installation:

1. The default memlock limit (`ulimit -l`) is typically insufficient, causing HashiCorp Vault `mlock` system calls to fail. In Rootless Podman environments, processes are mapped via UID to a standard host user and inherit existing permission restrictions. To resolve this, the following configuration should be applied to `/etc/security/limits.conf`:

    ```shell
    sudo tee -a /etc/security/limits.conf <<EOT
    ${USER}    soft    memlock    unlimited
    ${USER}    hard    memlock    unlimited
    EOT
    ```

    This configuration enables the Vault process within the user namespace to lock memory. A system reboot is required for these changes to take effect, preventing sensitive data from being paged to unencrypted swap space.

2. For the initial deployment, execute:

    ```shell
    podman compose up --build
    ```

3. Once the containers are created, use the following command to start the services:

    ```shell
    podman compose up -d
    ```

4. The default environment is set to `DEBIAN_FRONTEND=noninteractive`. To access a container for inspection or modification, execute:

    ```shell
    podman exec -it iac-controller-base bash
    ```

    In this context, `iac-controller-base` refers to the root container name for the project.

5. The default container status after running `podman compose --profile all up -d` and `podman ps -a` should resemble the following:

    ```text
    CONTAINER ID  IMAGE                                            COMMAND               CREATED         STATUS                   PORTS       NAMES
    974baf0177f6  docker.io/hashicorp/vault:2.0                    server -config=/v...  24 seconds ago  Up 14 seconds (healthy)  8200/tcp    iac-vault-server
    ea3b31db9a5c  localhost/on-premise-iac-controller:qemu-latest  /bin/bash -c whil...  24 seconds ago  Up 14 seconds                        iac-runner
    ```

> [!NOTE]
> **Resolved: Data Loss Warning**
> ~~When switching between Podman container and Native environments, all Libvirt resources provisioned by Terraform will be automatically deleted. This measure prevents permission and context conflicts associated with the Libvirt UNIX socket.~~

## B. Environment Switching: Container vs. Native

Option `9` in `./entry.sh` toggles between "Container" and "Native" environments.

This repo utilizes Podman as the container runtime to prevent SELinux permission conflicts. On systems with SELinux enabled (e.g., Fedora, RHEL, CentOS Stream), Docker containers run within the `container_t` domain by default. In such environments, the SELinux policy prohibits `container_t` from connecting to the `virt_var_run_t` UNIX socket, even if `/var/run/libvirt/libvirt-sock` is correctly mounted with `0770` permissions and proper group ownership. This results in **Permission denied** errors for `virsh` or the Terraform libvirt provider.

Conversely, the process context (`task_struct`) of rootless Podman is typically the user's `unconfined_t` or a similar SELinux type, rather than being restricted to `container_t`. Therefore, assuming the user is a member of the `libvirt` group, connection to the `libvirt` socket proceeds successfully without additional SELinux policy adjustments. If Docker must be used, alternative workarounds include disabling SELinux (not recommended), implementing custom SELinux modules, or enabling TCP connections for `libvirtd` at the cost of reduced security.

## C. Libvirt Permissions

> [!NOTE]
> Incorrect Libvirt file permissions will directly obstruct the [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest). The following permission checks should be performed before proceeding.

1. Ensure the user account is a member of the `libvirt` group.

    ```shell
    sudo usermod -aG libvirt $(whoami)
    ```

    A full logout and login, or a system reboot, is required for the group membership changes to take effect in the current shell session.

2. Modify the `libvirtd` configuration to delegate socket management to the `libvirt` group.

    ```shell
    # Using Vim
    sudo vim /etc/libvirt/libvirtd.conf

    # Using Nano
    sudo nano /etc/libvirt/libvirtd.conf
    ```

    Uncomment the following lines within the file:

    ```toml
    unix_sock_group = "libvirt"
    # ...
    unix_sock_rw_perms = "0770"
    ```

3. Override the systemd socket unit settings, as systemd configurations take precedence over `libvirtd.conf`.
    1. Open the systemd editor for the socket unit:

        ```shell
        sudo systemctl edit libvirtd.socket
        ```

    2. Insert the following configuration above the `### Edits below this comment will be discarded` line to ensure the settings are applied:

        ```toml
        [Socket]
        SocketGroup=libvirt
        SocketMode=0770
        ```

    Save and exit the editor (Press `Ctrl+O`, `Enter`, then `Ctrl+X` in Nano).

4. Restart the services in the following order to apply the changes.
    1. Reload the `systemd` manager configuration:

        ```shell
        sudo systemctl daemon-reload
        ```

    2. Stop all `libvirtd` related services to ensure a clean transition:

        ```shell
        sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
        ```

    3. Disable `libvirtd.service` to delegate service management to systemd socket activation:

        ```shell
        sudo systemctl disable libvirtd.service
        ```

    4. Restart the `libvirtd.socket`:

        ```shell
        sudo systemctl restart libvirtd.socket
        ```

5. Verification.
    1. Inspect the socket permissions; the output should indicate the `libvirt` group and `srwxrwx---` permissions.

        ```shell
        ls -la /var/run/libvirt/libvirt-sock
        ```

    2. Execute the `virsh` command as a non-root user:

        ```shell
        virsh list --all
        ```

Successful execution and the display of virtual machines—regardless of whether the list is empty—confirms that permissions are correctly configured.
