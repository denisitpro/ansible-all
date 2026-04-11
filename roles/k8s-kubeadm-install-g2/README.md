# Description  
* Role  install and configure k8s to ubuntu 24 - use kubeadm
* need set variable `k8s_master_group_name` = out host group

# Node Labeling

The role supports two independent methods for applying labels to K8s nodes. Both can be used simultaneously or separately. By default, neither method is enabled.

## Method 1: Manual Labels

Apply labels from a manually defined list in group_vars.

**Enable flag:** `k8s_enable_manual_labels: true`

**Configuration example** (`group_vars/<group>/label-hands.yml`):
```yaml
k8s_enable_manual_labels: true

k8s_node_labels_manual:
  - name: "k8s-fw-base"
    value: "system-base-100"
  - name: "k8s-node-type"
    value: "master"
  - name: "location"
    value: "eu-central"
```

**Ansible tags:** `k8s-label-nodes`, `k8s-label-manual`

## Method 2: Labels from Ansible Tags (Dynamic)

Apply labels based on host tags defined in the inventory file. Uses `ansible-set-tags` role to discover nodes dynamically.

**Enable flag:** `k8s_label_nodes_from_tags: true`

### Step 1: Add tags to inventory hosts

In `hosts` file:
```ini
[k8s_master_c1_sigma]
nbg1-c1-sigma-k8s-01.example.org k8s_role=master
nbg1-c1-sigma-k8s-02.example.org k8s_role=master

[k8s_worker_c1_sigma]
nbg1-c1-sigma-w-01.example.org k8s_role=worker
nbg1-c1-sigma-w-02.example.org k8s_role=ingress
```

### Step 2: Configure tag discovery

In `group_vars/<group>/k8s-label.yml`:
```yaml
k8s_label_nodes_from_tags: true

k8s_hosts_tag_configs:
  - tags:
      k8s_role: master
    output_var_name: k8s_master_nodes_list
  - tags:
      k8s_role: worker
    output_var_name: k8s_worker_nodes_list
```

### Step 3: (Optional) Customize labels

Base labels are defined in role defaults and always applied:
```yaml
# Master nodes get:
k8s_master_node_labels_base:
  - name: "k8s-fw-base"
    value: "system-base-100"
  - name: "k8s-node-type"
    value: "master"

# Worker nodes get:
k8s_worker_node_labels_base:
  - name: "k8s-fw-base"
    value: "system-base-100"
  - name: "k8s-node-type"
    value: "worker"
```

To add extra labels per environment:
```yaml
k8s_master_node_labels_extra:
  - name: "cloud_provider"
    value: "hetzner"
  - name: "region"
    value: "eu"

k8s_worker_node_labels_extra:
  - name: "gpu"
    value: "nvidia"
```

**Ansible tags:** `k8s-label-nodes`, `k8s-label-nodes-tags`

## Execution conditions

- **Manual labels** (`55-label-nodes-manual.yml`): runs on any node when `k8s_enable_manual_labels` is defined
- **Labels from tags - masters** (`60-label-master-nodes-from-ansible-tags.yml`): runs only on master nodes (`k8s_master is defined`)
- **Labels from tags - workers** (`61-label-worker-nodes-from-ansible-tags.yml`): runs only on worker nodes (`k8s_master is not defined`)

# Local ip address launch
need set variable  for master node
```commandline
k8s_cls_name: k8s-lb-local-01.beta-82.win
k8s_cls_ip: 10.15.2.100
k8s_local_network_force: true 
```

For worker node
```commandline
k8s_cls_name: k8s-lb-local-01.beta-82.win
k8s_local_network_force: true
```

## Calico backend

By default, `IPIP` (IP-in-IP) encapsulation is used.  
If you are using external firewalls (e.g. Hetzner Cloud Firewall), you must switch to `VXLAN` because Hetzner does not allow IPIP (L3) traffic through its firewall.

Set the following variables:

```yaml
k8s_calico_ipv4_encapsulation: VXLAN
k8s_calico_ipv4_ipip_mode: Never
k8s_calico_ipv4_vxlan_mode: Always
```

# Cilium install
Helm - required localhost installed

Check corrected work
```bash
export KUBECONFIG=~/.kube/sigma.conf
cilium status
```

# Commands
###  Create join token for worker nodes
```
export KUBECONFIG=/etc/kubernetes/admin.conf
kubeadm token create --print-join-command
```

## Troubleshooting

### Hard Reset (bypass kubeadm reset hang on Cilium cleanup)

If `kubeadm reset` hangs during Cilium cleanup, use this hard reset procedure:

#### Step 1: Stop kubelet and perform forced reset
```bash
# 1) Stop kubelet
sudo systemctl stop kubelet

# 2) Execute reset without cleanup-node (won't touch CRI/CNI)
sudo kubeadm reset --force \
  --cri-socket=/var/run/containerd/containerd.sock \
  --skip-phases=cleanup-node
```

#### Step 2: Manual CRI/CNI/Cilium cleanup
```bash
# 3) Stop container runtime
sudo systemctl stop containerd

# 4) Remove CNI configs and caches
sudo rm -rf /etc/cni/net.d/* /var/lib/cni/* /var/run/cni/*

# 5) Remove Cilium interfaces (ignore "Cannot find device" errors)
for i in cilium_host cilium_net; do sudo ip link del "$i" 2>/dev/null || true; done
# Remove possible veth interfaces for pods (lxc* for Cilium)
for i in $(ip -o link show | awk -F': ' '/^ *[0-9]+: lxc/{print $2}'); do sudo ip link del "$i" 2>/dev/null || true; done

# 6) Clean bpffs that holds Cilium BPF pins
mount | grep -E ' bpffs |cilium.*bpff?s' || true
# Usually /sys/fs/bpf
sudo umount /sys/fs/bpf 2>/dev/null || sudo umount -l /sys/fs/bpf 2>/dev/null || true
# Some Cilium installations mount /run/cilium/bpffs
sudo umount /run/cilium/bpffs 2>/dev/null || sudo umount -l /run/cilium/bpffs 2>/dev/null || true
sudo rm -rf /sys/fs/bpf/* /run/cilium/bpffs/* 2>/dev/null || true

# 7) Clean containerd runtime artifacts for k8s (if tasks remain)
sudo rm -rf /run/containerd/io.containerd.runtime.v2.task/k8s.io/*
sudo rm -rf /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io/*

# 8) Start containerd back
sudo systemctl start containerd

# 9) Clean kubelet directories (if not cleaned yet)
sudo rm -rf /var/lib/kubelet/* /var/lib/kubelet/pki/* /var/lib/kubelet/plugins/* /var/lib/kubelet/plugins_registry/* 2>/dev/null || true
sudo mkdir -p /var/lib/kubelet
sudo systemctl start kubelet
```

#### Optional: Using crictl for additional cleanup
If `crictl` is installed, you can perform additional cleanup before step 8:

```bash
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock stopp $(sudo crictl pods -q) 2>/dev/null || true
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock rmp -f $(sudo crictl pods -q) 2>/dev/null || true
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock rm -f $(sudo crictl ps -aq) 2>/dev/null || true
```

#### Verification
After cleanup, verify that everything is clean:

```bash
# Should not have any network namespaces from pods
sudo ls -l /var/run/netns || true

# cilium_* and lxc* interfaces should be gone
ip link | egrep 'cilium_|^ *[0-9]+: lxc' || true
```

