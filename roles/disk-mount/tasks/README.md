# Example array

```yaml
disk_mounts:
  - device: /dev/sdb
    fs: ext4
    mount_point: /mnt/disk1
    opts: noatime
  - device: /dev/sdc
    fs: ext4
    mount_point: /mnt/disk2
  - device: /dev/sdd
    fs: xfs
    mount_point: /mnt/disk3
    opts: defaults
```