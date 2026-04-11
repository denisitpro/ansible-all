# Disk Mount Role

This role handles disk mounting with optional LUKS encryption support.

## Basic Example (without encryption)

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

## LUKS Encryption Examples

### Using keyfile (recommended for automation)

```yaml
disk_mounts:
  - device: /dev/sdb
    fs: ext4
    mount_point: /mnt/encrypted1
    opts: noatime
    luks_enabled: true
    luks_name: encrypted_data         # Name for /dev/mapper/encrypted_data
    luks_keyfile: /root/.luks/disk1.key
    luks_generate_keyfile: true       # Auto-generate keyfile if not exists
    luks_auto_unlock: true            # Add to crypttab for auto-unlock at boot
```

### Using passphrase

```yaml
disk_mounts:
  - device: /dev/sdc
    fs: ext4
    mount_point: /mnt/encrypted2
    luks_enabled: true
    luks_name: secure_storage
    luks_passphrase: "{{ vault_luks_passphrase }}"  # Use Ansible Vault!
    luks_add_to_crypttab: true        # Add to crypttab (manual unlock required)
```

### Advanced LUKS options

```yaml
disk_mounts:
  - device: /dev/sdd
    fs: xfs
    mount_point: /mnt/secure
    opts: defaults,noatime
    luks_enabled: true
    luks_name: secure_xfs
    luks_keyfile: /root/.luks/secure.key
    luks_generate_keyfile: true
    luks_type: luks2                  # LUKS version (luks1 or luks2)
    luks_cipher: aes-xts-plain64      # Cipher specification
    luks_hash: sha256                 # Hash algorithm
    luks_sector_size: 4096            # Sector size (for luks2)
    luks_crypttab_opts: luks,discard  # Options for crypttab
    luks_auto_unlock: true
```

## LUKS Parameters Reference

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `luks_enabled` | No | `false` | Enable LUKS encryption |
| `luks_name` | No | `luks_<device>` | Name for the mapped device |
| `luks_keyfile` | No* | - | Path to keyfile for encryption |
| `luks_passphrase` | No* | - | Passphrase for encryption (use Vault!) |
| `luks_generate_keyfile` | No | `false` | Auto-generate keyfile if not exists |
| `luks_type` | No | `luks2` | LUKS format version |
| `luks_cipher` | No | (system default) | Cipher specification |
| `luks_hash` | No | (system default) | Hash algorithm |
| `luks_sector_size` | No | (system default) | Sector size (luks2 only) |
| `luks_crypttab_opts` | No | `luks` / `luks,noauto,nofail` | Options for crypttab entry |
| `luks_auto_unlock` | No | `true` | Add to crypttab (keyfile only) |
| `luks_add_to_crypttab` | No | `false` | Add to crypttab (passphrase mode) |
| `add_to_fstab` | No | `false` | Add to fstab for manual LUKS mounts |
| `mount_at_boot` | No | `true` | Add regular mounts to fstab |

*Either `luks_keyfile` or `luks_passphrase` is required when `luks_enabled: true`

## Important: LUKS with Passphrase Behavior

**By default**, when using LUKS with passphrase (without keyfile):
- The device is **NOT** added to `/etc/crypttab`
- The mount point is **NOT** added to `/etc/fstab`
- Server boots normally without password prompts
- You must manually unlock and mount after SSH connection

This prevents the server from hanging at boot waiting for password input.

## Auto-generated Helper Scripts

When using LUKS with passphrase (without keyfile) and `add_to_fstab: false`, the role automatically creates helper scripts in `/opt/luks/`:

- `/opt/luks/unlock-mount_<luks_name>.sh` - Unlock LUKS and mount filesystem
- `/opt/luks/lock-umount_<luks_name>.sh` - Unmount filesystem and lock LUKS

### Script Features

Both scripts include safety features:
- **Confirmation prompt** - requires typing `yes` to proceed
- **Skip confirmation** - use `-y` or `--yes` flag
- **Force mode** - use `-f` or `--force` flag (lock script only)

The lock script additionally:
- Checks if mount point is in use (via `lsof`)
- Shows list of processes using the mount
- Requires second confirmation for force unmount
- Uses lazy unmount (`umount -l`) when forced
- Handles LUKS device still in use scenarios

### Usage Examples

```bash
# Unlock and mount (with confirmation prompt)
sudo /opt/luks/unlock-mount_psql-data.sh

# Unlock and mount (skip confirmation)
sudo /opt/luks/unlock-mount_psql-data.sh -y

# Lock and unmount (with confirmation prompt)
sudo /opt/luks/lock-umount_psql-data.sh

# Lock and unmount (skip first confirmation, but ask for force if in use)
sudo /opt/luks/lock-umount_psql-data.sh -y

# Force lock and unmount (no confirmations, use with caution!)
sudo /opt/luks/lock-umount_psql-data.sh --force
```

### Typical Workflow

```bash
# After server boot, SSH in and unlock:
sudo /opt/luks/unlock-mount_psql-data.sh
# Enter: yes
# Enter LUKS passphrase when prompted

# Start your services
cd /opt/docker/psql && docker compose up -d

# Before maintenance/shutdown:
cd /opt/docker/psql && docker compose down
sudo /opt/luks/lock-umount_psql-data.sh
# Enter: yes
```

## Requirements

- `community.crypto` collection (for `luks_device` module)
- `community.general` collection (for `crypttab` module)
- `cryptsetup` package (installed automatically)

## Notes

- LUKS encryption is only supported for device-based mounts (not UUID-based)
- For production use, always store passphrases in Ansible Vault
- Keyfile-based encryption is recommended for automated setups
- The keyfile is generated with 4096 bytes from `/dev/urandom`

## Manual LUKS Management

### Opening (unlocking) a LUKS container

```bash
# Using auto-generated script (recommended)
sudo /opt/luks/unlock-mount_psql-data.sh

# Or manually using passphrase (will prompt for password)
sudo cryptsetup luksOpen /dev/sdb psql-data

# Using keyfile
sudo cryptsetup luksOpen /dev/sdb psql-data --key-file /root/.luks/psql-data.key

# Or via cryptdisks (if configured in /etc/crypttab)
sudo cryptdisks_start psql-data
```

### Mounting the filesystem

```bash
# After opening LUKS, mount the mapper device
sudo mount /dev/mapper/psql-data /mnt/psql-data

# Or mount all fstab entries
sudo mount -a
```

### Checking status

```bash
# List all open LUKS containers
sudo dmsetup ls --target crypt

# Check specific container status
sudo cryptsetup status psql-data

# View LUKS header information
sudo cryptsetup luksDump /dev/sdb
```

### Unmounting and closing

```bash
# Unmount the filesystem first
sudo umount /mnt/psql-data

# Close the LUKS container
sudo cryptsetup luksClose psql-data

# Or via cryptdisks (if configured in /etc/crypttab)
sudo cryptdisks_stop psql-data
```

### Full startup sequence (manual unlock with passphrase)

```bash
# 1. Open LUKS container
sudo cryptsetup luksOpen /dev/sdb psql-data

# 2. Mount filesystem
sudo mount /dev/mapper/psql-data /mnt/psql-data

# 3. Start your service
docker compose start psql
```

### Full shutdown sequence

```bash
# 1. Stop services using the mount
docker compose stop psql

# 2. Unmount filesystem
sudo umount /mnt/psql-data

# 3. Close LUKS container
sudo cryptsetup luksClose psql-data
```

### Removing LUKS container completely

```bash
# 1. Stop services using the mount
docker compose stop psql

# 2. Unmount the filesystem
sudo umount /mnt/psql-data

# 3. Close the LUKS container
sudo cryptsetup luksClose psql-data

# 4. (Optional) Erase LUKS header - WARNING: ALL DATA WILL BE LOST!
sudo cryptsetup erase /dev/sdb

# Or quickly overwrite the header
sudo dd if=/dev/zero of=/dev/sdb bs=1M count=10

# 5. Remove entry from /etc/crypttab
sudo nano /etc/crypttab
# Delete the line with your LUKS device

# 6. Remove entry from /etc/fstab
sudo nano /etc/fstab
# Delete the line with /dev/mapper/psql-data
```

### Troubleshooting

```bash
# Check if device is a LUKS container
sudo cryptsetup isLuks /dev/sdb && echo "LUKS" || echo "Not LUKS"

# Check what's using the mount (if umount fails)
sudo lsof +D /mnt/psql-data

# Force close mapper (use with caution!)
sudo dmsetup remove psql-data
```

