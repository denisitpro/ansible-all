---
meta: test
---

# Description
Unit for start hands, default time launch 120 sec

# Hands stop
pkill stress 

# Find pid and cpu bind
pidoff stress
taskset -pc pid


# Set CPU affinity count 
ansible cpu count start 1, OS cpu count start 0


Example use cpu 3 and 4, os number - 2 and 3
```
cpu_affinity_core: "2-{{ansible_processor_vcpus-1}}"
```