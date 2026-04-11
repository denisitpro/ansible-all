# Multi-Ingress Deployment Patterns (NGINX + Traefik)

This document describes two practical patterns for running `ingress-nginx` and `traefik` in the same cluster with this role.

## Important Current Behavior

The role discovers ingress nodes from inventory host variable `k8s_ingress`.
It supports both single value and comma-separated values:

- `k8s_ingress=nginx` for NGINX nodes
- `k8s_ingress=traefik` for Traefik nodes
- `k8s_ingress=nginx,traefik` for dual-role nodes

This keeps backward compatibility with existing inventories and enables same-host dual ingress placement.

Role files involved:
- `tasks/25-set-ingress-label-from-ansible.yml`
- `templates/ingress-nginx-values.yaml.j2`
- `templates/traefik-values.yaml.j2`

---

## Variant A: NGINX and Traefik on Different Hosts (80/443)

### Inventory example (`hosts`)

```ini
[k8s_ingress_nbg1]
nbg1-i-150.example.com k8s_role=worker k8s_ingress=nginx
nbg1-t-170.example.com k8s_role=worker k8s_ingress=traefik

[k8s_ingress_fsn1]
fsn1-i-250.example.com k8s_role=worker k8s_ingress=nginx
fsn1-t-270.example.com k8s_role=worker k8s_ingress=traefik
```

### Variables example (`group_vars/k8s_components_*/ingress.yml`)

```yaml
nginx_ingress_mode: "network_mode"   # NGINX listens on node 80/443

nginx_ingress_use_node_selector: true
nginx_ingress_node_selector:
  ingress.nginx/enabled: enabled
```

### Variables example (`group_vars/k8s_components_*/traefik.yml`)

```yaml
traefik_service_mode: "network_mode"     # Traefik listens on node 80/443
traefik_deployment_kind: "DaemonSet"

traefik_use_node_selector: true
traefik_auto_node_selector_from_inventory_tag: true
# auto selector uses hosts with k8s_ingress=traefik
```

### Notes

- Works because NGINX and Traefik are on different hosts, so no port collision on `80/443`.
- Recommended when both controllers must be externally reachable on standard ports.

---

## Variant B: NGINX and Traefik on the Same Host(s), Different Ports (30000+)

For this pattern, both controllers run on same nodes and expose different NodePorts.

### Recommended approach

1. Tag shared ingress hosts as `k8s_ingress=nginx,traefik`.
2. Deploy NGINX with `node_port` mode (for example `30080/30443`).
3. Deploy Traefik with `node_port` mode (for example `32080/32443`).
4. Keep auto-discovery enabled for both controllers.

### Inventory example (`hosts`)

```ini
[k8s_ingress_nbg1]
nbg1-i-150.example.com k8s_role=worker k8s_ingress=nginx,traefik

[k8s_ingress_fsn1]
fsn1-i-250.example.com k8s_role=worker k8s_ingress=nginx,traefik
```

### Variables example (`group_vars/k8s_components_*/ingress.yml`)

```yaml
nginx_ingress_mode: "node_port"
nginx_ingress_node_port:
  http: "30080"
  https: "30443"

nginx_ingress_use_node_selector: true
nginx_ingress_node_selector:
  ingress.nginx/enabled: enabled
```

### Variables example (`group_vars/k8s_components_*/traefik.yml`)

```yaml
traefik_service_mode: "node_port"
traefik_web_node_port: 32080
traefik_websecure_node_port: 32443

# Keep auto-discovery enabled (supports k8s_ingress=nginx,traefik)
traefik_auto_node_selector_from_inventory_tag: true
```

### Notes

- This avoids changing role logic and works with current inventory model.
- Traffic model is external LB -> nodeIP:`30080/30443` for NGINX and nodeIP:`32080/32443` for Traefik.
- `k8s_ingress=traefik` is not used in this variant.

---

## Notes on `k8s_ingress`

- Use single value for dedicated-node setup:
  - `k8s_ingress=nginx`
  - `k8s_ingress=traefik`
- Use comma-separated value for shared-node setup:
  - `k8s_ingress=nginx,traefik`

Matching is whitespace-tolerant, so these are equivalent:
- `k8s_ingress=nginx,traefik`
- `k8s_ingress=nginx, traefik`
