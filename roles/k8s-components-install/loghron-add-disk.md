# Adding Additional Disk to Longhorn Node

This guide explains how to add an additional disk to a Longhorn node in your Kubernetes cluster. This is useful when you need to expand storage capacity or add new storage devices.

## Prerequisites

- Access to the Kubernetes cluster with `kubectl` configured
- Longhorn system namespace exists (`longhorn-system`)
- The target node is already registered in Longhorn
- The disk is physically attached and mounted on the node

## Important Notes

- **Disk Path Uniqueness**: Hetzner node disk paths are unique, so you need to verify the disk mount path
- **Fstab Verification**: Always check `/etc/fstab` on the target node to confirm the mount path
- **Backup**: Consider backing up your Longhorn configuration before making changes

## Configuration Variables

Set these variables according to your environment:

```bash
# Node to patch (must be a registered Longhorn node)
NODE_NAME="nbg1-w-01"

# Human-friendly disk key (must NOT contain '/' characters)
DISK_KEY="hc-volume-103112290"

# Mount path as specified in your /etc/fstab
DISK_PATH="/mnt/HC_Volume_103112290"
```

## Step-by-Step Instructions

### Step 1: Verify Node Exists

First, ensure the target node exists in Longhorn:

```bash
kubectl -n longhorn-system get node.longhorn.io "${NODE_NAME}"
```

### Step 2: Verify Disk Mount on Node

Connect to the target node and verify the disk is properly mounted:

```bash
# Check if the mount point exists
DISK_KEY="hc-volume-103112290"
DISK_PATH="/mnt/HC_Volume_103112290"
ls -la "${DISK_PATH}"

# Verify mount in /etc/fstab
grep "${DISK_PATH}" /etc/fstab

# Check disk usage
df -h "${DISK_PATH}"
```

### Step 3: Ensure Disks Section Exists

Create the `.spec.disks` section if it doesn't exist (this is a no-op if already present):

```bash
kubectl -n longhorn-system patch node.longhorn.io "${NODE_NAME}" \
  --type json \
  -p '[{"op":"add","path":"/spec/disks","value":{}}]' 2>/dev/null || true
```

### Step 4: Add the New Disk

Add the new disk entry to the Longhorn node configuration:

```bash
kubectl -n longhorn-system patch node.longhorn.io "${NODE_NAME}" \
  --type json \
  -p '[{
    "op":"add",
    "path":"/spec/disks/'"${DISK_KEY}"'",
    "value":{
      "allowScheduling":true,
      "evictionRequested":false,
      "path":"'"${DISK_PATH}"'",
      "storageReserved":2147483648,
      "tags":[],
      "diskType":"filesystem",
      "diskDriver":""
    }
  }]'
```

### Step 5: Verify Configuration

Check that the disk was added successfully:

```bash
# Quick verification of the disk path
kubectl -n longhorn-system get node.longhorn.io "${NODE_NAME}" \
  -o jsonpath='{.spec.disks.'"${DISK_KEY}"'.path}'; echo

# Detailed view of the node configuration
kubectl -n longhorn-system get node.longhorn.io "${NODE_NAME}" -o yaml
```

## Configuration Parameters Explained

- **`allowScheduling`**: Set to `true` to allow Longhorn to schedule volumes on this disk
- **`evictionRequested`**: Set to `false` to prevent forced eviction of volumes
- **`path`**: The mount path where the disk is accessible
- **`storageReserved`**: Reserved space in bytes (0 = no reservation)
- **`tags`**: Array of tags for disk identification and filtering
- **`diskType`**: Type of disk (usually "filesystem")
- **`diskDriver`**: Disk driver type (empty for default)

## Troubleshooting

### Common Issues

1. **Node Not Found**: Ensure the node name is correct and exists in Longhorn
2. **Permission Denied**: Verify you have sufficient RBAC permissions
3. **Invalid Path**: Check that the disk path exists and is accessible
4. **Disk Already Exists**: The operation will fail if the disk key already exists

### Verification Commands

```bash
# Check node status
kubectl -n longhorn-system get node.longhorn.io

# View node details
kubectl -n longhorn-system describe node.longhorn.io "${NODE_NAME}"

# Check Longhorn UI for disk appearance
# Access Longhorn UI and navigate to Node tab
```

## Safety Considerations

- Always verify disk paths before applying changes
- Test the procedure on a non-production environment first
- Ensure the disk has sufficient space and performance characteristics
- Monitor Longhorn logs for any errors after adding the disk

## Next Steps

After successfully adding the disk:

1. Monitor the Longhorn UI to see the new disk
2. Verify that volumes can be scheduled on the new disk
3. Consider setting up monitoring for disk usage and performance
4. Update your documentation with the new disk configuration
