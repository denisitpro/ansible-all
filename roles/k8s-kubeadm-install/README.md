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

# Todo
* local iface - need support env, current state harcode - level task
* calico bird support specific bind iface or address
* calico typha support specific bind iface or address