

locals {
  vm_username      = data.vault_generic_secret.variables.data["vm_username"]
  private_key_path = data.vault_generic_secret.variables.data["ssh_private_key_path"]
}


# 1. 定義主機資訊
# 這是 Ansible Provider 的標準作法，將主機註冊到 Terraform State 中
resource "ansible_host" "harbor_node" {
  name   = "harbor-microk8s-node-00"
  groups = ["harbor_nodes"]

  variables = {
    # 定義連線變數 (Inventory Vars)
    ansible_host = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_ip_list[0]
    ansible_user = local.vm_username
    # 注意：Ansible Provider 預期 private_key_file 是路徑，不是內容
    ansible_ssh_private_key_file = local.private_key_path
    ansible_python_interpreter   = "/usr/bin/python3"

    # 關閉 Host Key Checking (避免首次連線互動卡住)
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
  }
}

# 2. 執行 Playbook
# 使用原生的 ansible_playbook 資源取代 null_resource
resource "ansible_playbook" "harbor_trust" {
  playbook   = "${path.module}/ansible/harbor_trust.yaml"
  name       = ansible_host.harbor_node.name
  groups     = ansible_host.harbor_node.groups
  replayable = true # 允許在 Apply 時重複執行 (類似 null_resource 的 trigger)

  # 定義要傳入 Playbook 的額外變數
  extra_vars = {
    # 我們將連線資訊再次明確傳入，確保即使沒有設定 dynamic inventory plugin 也能連線
    ansible_host                 = ansible_host.harbor_node.variables["ansible_host"]
    ansible_user                 = ansible_host.harbor_node.variables["ansible_user"]
    ansible_ssh_private_key_file = ansible_host.harbor_node.variables["ansible_ssh_private_key_file"]
    ansible_ssh_common_args      = ansible_host.harbor_node.variables["ansible_ssh_common_args"]

    # 傳入 Harbor 網域變數
    harbor_domain = "harbor.iac.local"
  }

  # 確保在 Host 定義好且 Helm 部署完後才執行
  depends_on = [
    helm_release.harbor,
    ansible_host.harbor_node
  ]
}
