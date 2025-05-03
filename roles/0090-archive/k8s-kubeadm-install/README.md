# Description  
* Role  install and configure k8s to ubuntu 24 - use kubeadm
* need set variable `k8s_master_group_name` = out host group



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



