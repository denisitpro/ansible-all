# Example extend pvc 
kubectl patch pvc/data-loki-ingester-1 --patch '{"spec": {"resources": {"requests": {"storage":"12Gi"}}}}' -n loki


Если будет ошибка 
```
Error from server (Forbidden): admission webhook "validator.longhorn.io" denied the request: error while CheckReplicasSizeExpansion for volume pvc-e7a49dc3-b8c9-404e-8cbc-6736e1edf139: cannot schedule 2147483648 more bytes to disk 8bc2b55d-3867-4ad5-a9b9-fd285c9b1a71 with &{DiskUUID:8bc2b55d-3867-4ad5-a9b9-fd285c9b1a71 StorageAvailable:26004684800 StorageMaximum:32196526080 StorageReserved:0 StorageScheduled:32212254720 OverProvisioningPercentage:100 MinimalAvailablePercentage:15}
```

То значит на loghorn на дисках места мало, надо или докинуть места или перебалансить так - чтобы диск оказался на одах где место есть

ребалансить можно просто удаляя реплику она сама создаться где норм место. Есть еще опция Replica Soft Anti-Affinity но с ней не очень живут тома кафки, так что только в тех кластерах где нет кафки