# Description  
* Role  install and configure k8s to ubuntu 22 - use kubeadm
* Another distribution not testing
* Test use servers - one interface
* need set variable `k8s_master_group_name` = out host group
* join worked node need hands get token for join - use control panel node. todo ned autmation use delegation 
```
export KUBECONFIG=/etc/kubernetes/admin.conf
kubeadm token create --print-join-command
```

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

# Todo
* local iface - need support env, current state harcode - level task
* calico bird support specific bind iface or address
* calico typha support specific bind iface or address
