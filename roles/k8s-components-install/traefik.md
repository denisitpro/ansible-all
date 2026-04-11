# Traefik Installation Examples

## Basic Configuration

Minimal setup with NodePort exposure and 2 replicas:

```yaml
helm_traefik_version: "39.0.1"
helm_traefik_namespace: "traefik"

# Basic deployment
traefik_replicas: 2
traefik_deployment_kind: "Deployment"
traefik_ingress_class_is_default_class: false
traefik_dashboard_enabled: false
traefik_service_mode: "node_port"

# NodePort configuration
traefik_web_node_port: 32080
traefik_websecure_node_port: 32443

# Logging (defaults: access logs enabled in JSON format)
traefik_log_level: "INFO"
# traefik_access_log_enabled: true  # enabled by default
# traefik_log_format: "json"        # JSON by default
# traefik_access_log_format: "json" # JSON by default
```

## Proxy Protocol Configuration

For external load balancers (e.g., Hetzner LB) with Proxy Protocol enabled:

```yaml
helm_traefik_version: "39.0.1"
helm_traefik_namespace: "traefik"

traefik_replicas: 2

# NodePort configuration
traefik_web_node_port: 32080
traefik_websecure_node_port: 32443

# Proxy Protocol support
# Add your load balancer IP(s)
traefik_proxy_protocol:
  ipv4:
    - 46.225.44.132/32  # Hetzner LB IP

# Important: Service uses externalTrafficPolicy: Local by default for NodePort
# This preserves source IP when using Proxy Protocol
```

**Note:** When using NodePort with Proxy Protocol, the service automatically sets `externalTrafficPolicy: Local` to preserve client IPs. This is required for Proxy Protocol to work correctly.

## Cloudflare + Load Balancer Configuration

For traffic: **Internet → Cloudflare → Hetzner LB → Traefik**

```yaml
helm_traefik_version: "39.0.1"
helm_traefik_namespace: "traefik"

traefik_replicas: 2

# NodePort configuration
traefik_web_node_port: 32080
traefik_websecure_node_port: 32443

# Proxy Protocol support (Hetzner LB IP)
# LB sends Proxy Protocol header with Cloudflare IP as source
traefik_proxy_protocol:
  ipv4:
    - 46.225.44.132/32  # Hetzner LB IP

# Real IP detection (Cloudflare IPs)
# Cloudflare adds X-Forwarded-For headers with real client IP
traefik_real_ip:
  ipv4:
    - 173.245.48.0/20
    - 103.21.244.0/22
    - 103.22.200.0/22
    - 103.31.4.0/22
    - 141.101.64.0/18
    - 108.162.192.0/18
    - 190.93.240.0/20
    - 188.114.96.0/20
    - 197.234.240.0/22
    - 198.41.128.0/17
    - 162.158.0.0/15
    - 104.16.0.0/13
    - 104.24.0.0/14
    - 172.64.0.0/13
    - 131.0.72.0/22
  ipv6:
    - 2400:cb00::/32
    - 2606:4700::/32
    - 2803:f800::/32
    - 2405:b500::/32
    - 2405:8100::/32
    - 2a06:98c0::/29
    - 2c0f:f248::/32
```

**How it works:**
1. Cloudflare receives request from real client (e.g., 1.2.3.4)
2. Cloudflare forwards to Hetzner LB with X-Forwarded-For: 1.2.3.4
3. Hetzner LB sends Proxy Protocol header to Traefik with Cloudflare IP as source
4. Traefik trusts both Proxy Protocol from LB and X-Forwarded-For from Cloudflare IPs

## Advanced Configuration

With proxy protocol, body size limits, and real IP detection:

```yaml
helm_traefik_version: "39.0.1"
helm_traefik_namespace: "traefik"

# Deployment with node selector
traefik_replicas: 3
traefik_deployment_kind: "Deployment"
traefik_use_node_selector: true
traefik_node_selector:
  ingress.traefik/enabled: "enabled"

# IngressClass configuration
traefik_ingress_class_is_default_class: false
traefik_dashboard_enabled: true

# HostPort mode (alternative to NodePort)
traefik_service_mode: "host_port"
traefik_web_host_port: 80
traefik_websecure_host_port: 443

# Proxy Protocol support
traefik_proxy_protocol:
  ipv4:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16

# Real IP detection (e.g., Cloudflare)
traefik_real_ip:
  ipv4:
    - 173.245.48.0/20
    - 103.21.244.0/22
    - 103.22.200.0/22
  ipv6:
    - 2400:cb00::/32
    - 2606:4700::/32

# Request body size limit (bytes)
traefik_body_size: 10485760  # 10 MB

# Logging (access logs enabled by default in JSON)
traefik_log_level: "DEBUG"
# Override format if needed:
# traefik_log_format: "common"        # use "common" instead of "json"
# traefik_access_log_format: "common" # use "common" instead of "json"
```

## Disable Access Logs

If you need to disable access logs:

```yaml
traefik_access_log_enabled: false
```

## Service Mode

Configure how Traefik service is exposed:

```yaml
# node_port | cluster_ip | host_port | network_mode
traefik_service_mode: "cluster_ip"

# Deployment | DaemonSet
traefik_deployment_kind: "Deployment"
```

- `node_port` (default): opens `traefik_web_node_port`/`traefik_websecure_node_port` on nodes
- `cluster_ip`: creates internal ClusterIP service only (no NodePorts on nodes)
- `host_port`: binds pod `hostPort` values and uses ClusterIP service
- `network_mode`: enables `hostNetwork` and binds Traefik directly to node ports (80/443 by default), without hostPort NAT
- `traefik_deployment_kind: "DaemonSet"`: runs one Traefik pod per selected node (recommended with `network_mode`)

Backward compatibility: existing `traefik_use_host_port: true` is still supported and treated as `host_port` when `traefik_service_mode` is not set.

## Activation

Uncomment in `tasks/main.yml`:

```yaml
- ansible.builtin.import_tasks: 135-traefik.yml
  delegate_to: "{{ k8s_master_init_host }}"
  run_once: true
  when: "'traefik' in helm_componets_list"
  tags:
    - k8s
    - k8s-addition
    - k8s-traefik
```

Add to `helm_componets_list`:

```yaml
helm_componets_list:
  - traefik
```

## Example IngressRoute (native) + ACL

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: acl-whitelist
  namespace: traefik
spec:
  ipAllowList:
    sourceRange:
      - 10.0.0.0/8
      - 192.168.10.10/32

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.example.com`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
      kind: Rule
      middlewares:
        - name: acl-whitelist
      services:
        - name: api@internal
          kind: TraefikService
  tls:
    secretName: traefik-example-com-tls

# Optional cert-manager Certificate
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-dashboard-cert
  namespace: traefik
spec:
  secretName: traefik-example-com-tls
  dnsNames:
    - traefik.example.com
  issuerRef:
    kind: ClusterIssuer
    name: cloudflare-issuer-dns-challenge
```

## Example Ingress (Kubernetes)

Use this when you want standard `Ingress` resources with Traefik ingress class.
This example expects dashboard service port exposure to be enabled (`traefik_dashboard_service_expose: true`).

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: acl-whitelist
  namespace: traefik
spec:
  ipAllowList:
    sourceRange:
      - 10.0.0.0/8
      - 192.168.10.10/32

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-dashboard
  namespace: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-acl-whitelist@kubernetescrd
    cert-manager.io/cluster-issuer: cloudflare-issuer-dns-challenge
spec:
  ingressClassName: traefik
  rules:
    - host: traefik.example.com
      http:
        paths:
          - path: /dashboard
            pathType: Prefix
            backend:
              service:
                name: traefik
                port:
                  number: 8080
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: traefik
                port:
                  number: 8080
```

## NGINX Annotations Analogs (Traefik)

NGINX annotations and Traefik equivalents:

- `nginx.ingress.kubernetes.io/backend-protocol: GRPC` -> Traefik backend `scheme: h2c` (or `https` for gRPC over TLS).
- `nginx.ingress.kubernetes.io/grpc-backend: 'true'` -> same behavior via backend scheme (`h2c`/`https`).
- `nginx.ingress.kubernetes.io/protocol: h2c` -> `traefik.ingress.kubernetes.io/service.serversscheme: h2c`.
- `nginx.ingress.kubernetes.io/force-ssl-redirect: 'false'` and `ssl-redirect: 'false'` -> do not use redirect middleware, use `web` entrypoint.
- `nginx.ingress.kubernetes.io/use-regex: 'true'` -> `traefik.ingress.kubernetes.io/router.pathmatcher: PathRegexp` (Ingress) or `PathRegexp(...)` (IngressRoute).

### gRPC + TLS (without redirect web -> websecure)

#### NGINX source example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend
  namespace: dev-env
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: GRPC
    nginx.ingress.kubernetes.io/force-ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/grpc-backend: 'true'
    nginx.ingress.kubernetes.io/protocol: h2c
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/use-regex: 'true'
spec:
  ingressClassName: nginx
  rules:
    - host: backend-grpc.dev-env.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  name: grpc
  tls:
    - hosts:
        - dev-env.example.com
        - '*.dev-env.example.com'
      secretName: wildcard-dev-env-example-com-tls
```

#### Traefik Ingress analog

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend
  namespace: dev-env
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/service.serversscheme: h2c
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - dev-env.example.com
        - '*.dev-env.example.com'
      secretName: wildcard-dev-env-example-com-tls
  rules:
    - host: backend-grpc.dev-env.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  name: grpc
```

#### Traefik IngressRoute analog

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backend
  namespace: dev-env
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`backend-grpc.dev-env.example.com`) && PathPrefix(`/`)
      kind: Rule
      services:
        - name: backend
          port: grpc
          scheme: h2c
  tls:
    secretName: wildcard-dev-env-example-com-tls
```

### Regexp path

#### NGINX source example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-web
spec:
  ingressClassName: nginx
  rules:
    - host: example.com
      http:
        paths:
          - path: /path/route
            pathType: Prefix
            backend:
              service:
                name: frontend-web
                port:
                  name: http
          - path: /[a-z]{2}/path/route/(/|$)
            pathType: ImplementationSpecific
            backend:
              service:
                name: frontend-web
                port:
                  name: http
  tls:
    - hosts:
        - example.com
      secretName: example-com-tls
```

#### Traefik Ingress analog

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-web
  annotations:
    traefik.ingress.kubernetes.io/router.pathmatcher: PathRegexp
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - example.com
      secretName: example-com-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: ^/path/route(/|$)
            pathType: ImplementationSpecific
            backend:
              service:
                name: frontend-web
                port:
                  name: http
          - path: ^/[a-z]{2}/path/route(/|$)
            pathType: ImplementationSpecific
            backend:
              service:
                name: frontend-web
                port:
                  name: http
```

#### Traefik IngressRoute analog

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: frontend-web
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`example.com`) && (PathPrefix(`/path/route`) || PathRegexp(`^/[a-z]{2}/path/route(/|$)`))
      kind: Rule
      services:
        - name: frontend-web
          port: http
  tls:
    secretName: example-com-tls
```
