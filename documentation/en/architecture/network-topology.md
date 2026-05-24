# Network Topology

## Host OS Kernel Tuning: The Why

> [!IMPORTANT]
> The system operates under a Centralized Load Balancer architecture where inter-node communication primarily follows an **Asymmetric Routing** pattern. To ensure the operational integrity of **VIP (Keepalived)**, **PKI**, and **OCI** services, the Host machine must be configured with the following settings.

### Asymmetric Routing and Reverse Path Filtering

First, configure Reverse Path Filtering to **loose mode**. Under an asymmetric routing architecture, return packets may arrive from a different network interface. Strict Mode will flag this as IP spoofing and drop the packets directly.

```mermaid
sequenceDiagram
    autonumber
    participant Client as External Client (Internet)
    participant VIP as CLB VM (VIP Address)
    participant App as Backend Services (GitLab/Harbor)
    participant Host as Host OS (Kernel Tuning)

    Note over Client, Host: [Scenario 1: Asymmetric Routing]

    Client->>VIP: Ingress Request (via VIP)
    VIP->>App: Load Balance and Forward Request
    App-->>Host: Direct Return Packet to Client (Different Return Path)

    Note right of Host: Verify Path Validity (rp_filter=2)
    Host->>Client: Packet Successfully Sent (Route Success)

    Note over Client, Host: [Scenario 2: IP Forwarding]

    App->>Host: System Update / External Resource Request
    Host->>Client: Forward to Internet via Host (ip_forward=1)
    Client-->>Host: Data Return
    Host-->>App: Forward to Virtual Machine
```

### Bridge Netfilter and mTLS

Libvirt's bridge will send L2 traffic to the Host's iptables for processing by default. In high-traffic scenarios or complex mTLS handshakes, this usually causes double filtering and connection state tracking (Conntrack) conflicts. Therefore, **the bridge must be disabled from invoking `netfilter`**, allowing routing decisions to return to L3 processing.

```mermaid
graph LR
    subgraph Host ["Host OS (L2 Bridge Isolation)"]
        Bridge["Linux Bridge"]
        Bypass["bridge-nf-call-iptables=0<br/>bridge-nf-call-ip6tables=0"]
        NF["Netfilter<br/>(firewalld / ufw)"]
    end

    subgraph GitLab_VM ["GitLab VM (Client)"]
        GitLab["GitLab"]
        G_Bundle["Trust Bundle"]
    end

    subgraph CLB_VM ["CLB VM (Traffic Hub)"]
        VIP["VIP (Keepalived)"]
        HAProxy["HAProxy<br/>(TCP Passthrough)"]
    end

    subgraph Vault_VM ["Vault VM (Server)"]
        Vault["Vault"]
        V_Bundle["Trust Bundle"]
    end

    GitLab -- "1. mTLS Handshake Request" --> Bridge
    Bridge -- "2. Bypass Netfilter" --> VIP
    VIP --> HAProxy
    HAProxy -- "3. Forward Packet" --> Bridge
    Bridge -- "4. Bypass Netfilter Again" --> Vault

    Bridge -. "If bridge-nf-call=0 is not set" .-> NF
    NF -. "Block or Interrupt" .-> Fail["TLS Handshake Failed<br/>(Handshake Timeout / Connection Reset)"]

    GitLab <==>|"End-to-End mTLS Tunnel<br/>(Success)"| Vault

    classDef bypass fill:#90EE90,stroke:#2E8B57,color:black
    classDef fail fill:#FF9999,stroke:#CC0000,color:black
    class Bypass bypass
    class Fail fail
```

Failure to disable this may lead to mTLS failures between guests (e.g., between GitLab and Vault). After setting `bridge-nf-call-*=0`, pure L2 packets forwarded by the bridge will directly bypass the Host's Netfilter and no longer consume Conntrack resources. However, inter-segment L3 routing traffic will still be managed by the Host's Conntrack. Therefore, the total capacity and recycling efficiency of the Conntrack table must be increased, and TCP state validation must be relaxed to ensure connections are not mistakenly terminated during high traffic and HA failovers.

### MTU / MSS

Since the infrastructure MTU is set to 1450 (with overhead reserved for VXLAN encapsulation), the MSS must be forcibly modified in the Host's `mangle` table to prevent TCP packets from being too large, which would result in fragmentation or black hole issues.

> For the actual sysctl commands, see [Kernel Tuning](../configuration/kernel-tuning.md).

---

## Policy-Based Routing (PBR) on the Central LB

```mermaid
graph LR
subgraph Central_LB["Central LB"]
    direction TB
    RULE["ip rule: from &lt;VIP&gt; lookup rt_&lt;name&gt;"]

    subgraph PBR_Standard["Standard Segments<br>(L3 Symmetric)"]
        direction LR
        RT_GE["rt_gitlab_etcd<br>128.0/24 → gw .128.1"]
        RT_GM["rt_gitlab_minio<br>130.0/24 → gw .130.1"]
        RT_GP["rt_gitlab_postgres<br>127.0/24 → gw .127.1"]
        RT_GR["rt_gitlab_redis<br>129.0/24 → gw .129.1"]
        RT_HB["rt_harbor_bootstrapper<br>137.0/24 → gw .137.1"]
        RT_HE["rt_harbor_etcd<br>133.0/24 → gw .133.1"]
        RT_HF["rt_harbor_frontend<br>131.0/24 → gw .131.1"]
        RT_HM["rt_harbor_minio<br>135.0/24 → gw .135.1"]
        RT_HP["rt_harbor_postgres<br>132.0/24 → gw .132.1"]
        RT_HR["rt_harbor_redis<br>134.0/24 → gw .134.1"]
    end

    subgraph PBR_Vault["Vault Segment<br>(L2 Exception)"]
        RT_VF["rt_vault_frontend\n136.0/24\nscope link: ALL subnets"]
    end
end

subgraph Libvirt_Router["Libvirt Host Router"]
    GW_STD["172.16.xxx.1"]
end

subgraph Segments["Service Segments"]
    SEG_HF["Harbor Frontend<br>172.16.131.0/24"]
    SEG_HR["Harbor Redis<br>172.16.134.0/24"]
    SEG_HP["Harbor Postgres<br>172.16.132.0/24"]
    SEG_VF["Vault Frontend<br>172.16.136.0/24"]
end

RULE --> PBR_Standard
RULE --> PBR_Vault

RT_HR & RT_HP & RT_HF -->|"cross-subnet reply"| GW_STD
GW_STD --> SEG_HF & SEG_HR & SEG_HP

RT_VF -->|"L2 direct (bypass router)"| SEG_VF
RT_VF -->|"scope link all → L2 return"| SEG_HF

SEG_HF -->|"SYN → 172.16.134.250"| RT_HR
SEG_VF -->|"SYN → 172.16.136.250"| RT_VF
```
