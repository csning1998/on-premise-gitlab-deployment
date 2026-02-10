# Stage 1. Base Image
FROM ubuntu:24.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Python optimization
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Define ARGS (Defaults can be overridden by compose.yml)
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG LIBVIRT_GID=999
ARG USERNAME=iac-user

# Stage 2: Install dependencies and tools
# Use /etc/os-release instead of installing lsb-release, use gnupg explicitly, and clean up in the same layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    jq \
    openssh-client \
    genisoimage \
    python3 \
    python3-pip \
    python3-venv \
    libvirt-clients \
    qemu-utils \
    qemu-system-x86 \
    ca-certificates \
    gnupg \
    # Setup HashiCorp Repo (Robust way using os-release)
    && . /etc/os-release \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" | tee /etc/apt/sources.list.d/hashicorp.list \
    # Install HashiCorp Tools
    && apt-get update && apt-get install -y --no-install-recommends \
    packer \
    terraform \
    vault \
    # Install Ansible
    && pip3 install ansible passlib --break-system-packages \
    && ansible-galaxy collection install \
        ansible.posix \
        community.general \
        community.docker \
        community.kubernetes \
        community.crypto \
        community.hashi_vault \
    # Cleanup to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 3: User permission configuration: Remove default ubuntu user (UID 1000) to allow reusing UID 1000
#### a. Handle Libvirt Group for GID Conflict Resolution. If GID exists, do nothing; if not, create it.
#### b. Handle User Primary Group for GID Conflict Resolution
#### c. Create User. Assume that UID is available because we deleted 'ubuntu' above.
#### d. Dynamic Name Resolution by adding user to the actual Libvirt group 
####    for the cases where GID might be named 'kvm' or 'docker' instead of 'libvirt-host'

RUN userdel -r ubuntu 2>/dev/null || true && \
    (getent group ${LIBVIRT_GID} || groupadd -g ${LIBVIRT_GID} libvirt-host) && \
    (getent group ${HOST_GID} || groupadd -g ${HOST_GID} ${USERNAME}) && \
    useradd -u ${HOST_UID} -g ${HOST_GID} -m -s /bin/bash ${USERNAME} && \
    LIBVIRT_GROUP_NAME=$(getent group ${LIBVIRT_GID} | cut -d: -f1) && \
    usermod -aG "${LIBVIRT_GROUP_NAME}" ${USERNAME}

# Finalization
USER ${USERNAME}
WORKDIR /home/${USERNAME}
CMD ["/bin/bash"]
