# Host OS Kernel Tuning

> [!IMPORTANT]
> The system operates under a Centralized Load Balancer architecture where inter-node communication primarily follows an **Asymmetric Routing** pattern. To ensure the operational integrity of **VIP (Keepalived)**, **PKI**, and **OCI** services, the Host machine must be configured with the following settings.
>
> For the architectural rationale behind these settings, see [Network Topology](../architecture/network-topology.md).

## 1. Reverse Path Filtering and IP Forwarding

Configure Reverse Path Filtering to **loose mode**. Under an asymmetric routing architecture, return packets may arrive from a different network interface. Strict Mode will flag this as IP spoofing and drop the packets directly.

```shell
sudo sysctl -w net.ipv4.conf.all.rp_filter=2
sudo sysctl -w net.ipv4.conf.default.rp_filter=2
```

Enable IP forwarding (Foundation for L3 Routing):

```shell
sudo sysctl -w net.ipv4.ip_forward=1
```

## 2. Bridge Netfilter

```shell
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0
sudo sysctl -w net.bridge.bridge-nf-call-arptables=0
```

After setting `bridge-nf-call-*=0`, pure L2 packets forwarded by the bridge will directly bypass the Host's Netfilter and no longer consume Conntrack resources. However, inter-segment L3 routing traffic will still be managed by the Host's Conntrack. Therefore, the total capacity and recycling efficiency of the Conntrack table must be increased, and TCP state validation must be relaxed to ensure connections are not mistakenly terminated during high traffic and HA failovers:

```shell
sudo sysctl -w net.netfilter.nf_conntrack_max=2097152
sudo sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
```

## 3. MSS Clamping

Since the infrastructure MTU is set to 1450 (with overhead reserved for VXLAN encapsulation), the MSS must be forcibly modified in the Host's `mangle` table to prevent TCP packets from being too large, which would result in fragmentation or black hole issues.

```shell
sudo firewall-cmd --permanent --direct --add-rule ipv4 mangle FORWARD 0 -s 172.16.0.0/16 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
sudo firewall-cmd --permanent --direct --add-rule ipv4 mangle FORWARD 0 -d 172.16.0.0/16 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
sudo firewall-cmd --reload
```
