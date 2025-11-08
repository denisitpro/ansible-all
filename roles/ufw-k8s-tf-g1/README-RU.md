# Роль ufw-k8s-tf-g1

Специализированная роль для управления UFW правилами Kubernetes кластеров. Роль автоматически создает правила фаервола на основе данных из Terraform state.

## Описание

Роль предназначена для настройки UFW правил на master и worker нодах Kubernetes кластера. Правила создаются динамически на основе IP-адресов, извлеченных из Terraform state файлов.

## Зависимости

**Критически важно:** Роль полностью зависит от роли `terraform-read-remote-state-g3`, которая должна быть выполнена первой для извлечения IP-адресов из Terraform state.

Роль `terraform-read-remote-state-g3` создает переменные с IP-адресами серверов и Load Balancer в формате:
```yaml
k8s_master_dev_nodes:
  ipv4: ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
  ipv6: ["2001:db8::10", "2001:db8::11", "2001:db8::12"]

k8s_worker_dev_nodes:
  ipv4: ["10.0.2.20", "10.0.2.21", "10.0.2.22"]
  ipv6: ["2001:db8::20", "2001:db8::21", "2001:db8::22"]

k8s_master_lb:
  ipv4: ["167.235.110.61"]
  ipv6: ["2a01:4f8:1c1f:6899::1"]
```

## Конфигурация

### Формат переменной

Роль использует переменную `ufw_k8s_g1` с секциями `ipv4` и `ipv6`:

```yaml
ufw_k8s_g1:
  ipv4:
    - { name: "rule-name", protocol: "tcp", port: "80", source: "10.0.0.0/24" }
  ipv6:
    - { name: "rule-name-ipv6", protocol: "tcp", port: "443" }
```

### Параметры правил

- `name` - имя правила (используется как комментарий в UFW)
- `protocol` - протокол (`tcp`, `udp`)
- `port` - порт или диапазон портов (`80`, `443`, `30000:32767`)
- `source` - IP-адрес источника или список (опционально, по умолчанию `0.0.0.0/0`)
- `rule` - тип правила (опционально, по умолчанию `allow`)
- `direction` - направление (опционально, по умолчанию `in`)

**Важно:** Роль поддерживает как одиночные IP, так и списки IP-адресов в параметре `source`. Для списков роль автоматически создаст правило для каждого IP.

## Примеры конфигурации

### Master Node

Файл: `group_vars/k8s_master_c1_dev/ufw-k8s.yml`

```yaml
---
ufw_k8s_g1:
  ipv4:
    # Kubernetes master ports - access only from other k8s masters
    - { name: "etcd-server-client", protocol: "tcp", port: "2379", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "etcd-server-peer", protocol: "tcp", port: "2380", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "kubelet-api", protocol: "tcp", port: "10250", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "kubelet-api-worker", protocol: "tcp", port: "10250", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Future use for monitoring, by default listens on 127.0.0.1
    # - { name: "kube-scheduler", protocol: "tcp", port: "10251", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    # - { name: "kube-controller-manager", protocol: "tcp", port: "10252", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Cilium networking - from workers
    - { name: "cilium-health-check-worker", protocol: "tcp", port: "4240", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-bpf-worker", protocol: "tcp", port: "4000", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-hubble-worker", protocol: "tcp", port: "4244", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-wireguard-worker", protocol: "udp", port: "51871", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-default-vxlan-worker", protocol: "udp", port: "4789", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-vxlan-tunnel-worker", protocol: "udp", port: "8472", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-geneve-tunnel-worker", protocol: "udp", port: "6081", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Cilium networking - from masters
    - { name: "cilium-health-check", protocol: "tcp", port: "4240", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-bpf", protocol: "tcp", port: "4000", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-hubble", protocol: "tcp", port: "4244", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-wireguard", protocol: "udp", port: "51871", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-default-vxlan", protocol: "udp", port: "4789", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-vxlan-tunnel", protocol: "udp", port: "8472", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-geneve-tunnel", protocol: "udp", port: "6081", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # API server access from load balancers and external
    - { name: "kube-apiserver-any", protocol: "tcp", port: "6443"}
  
  ipv6:
    # API server access from load balancers (IPv6)
    - { name: "kube-apiserver-any", protocol: "tcp", port: "6443"}
```

### Worker Node

Файл: `group_vars/k8s_worker_c1_dev/ufw-k8s.yml`

```yaml
---
ufw_k8s_g1:
  ipv4:
    # Cilium networking - from masters
    - { name: "cilium-health-check", protocol: "tcp", port: "4240", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-bpf", protocol: "tcp", port: "4000", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-hubble", protocol: "tcp", port: "4244", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-wireguard", protocol: "udp", port: "51871", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-default-vxlan", protocol: "udp", port: "4789", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-vxlan-tunnel", protocol: "udp", port: "8472", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-geneve-tunnel", protocol: "udp", port: "6081", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Cilium networking - from workers
    - { name: "cilium-health-check-worker", protocol: "tcp", port: "4240", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-bpf-worker", protocol: "tcp", port: "4000", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-hubble-worker", protocol: "tcp", port: "4244", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-wireguard-worker", protocol: "udp", port: "51871", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-default-vxlan-worker", protocol: "udp", port: "4789", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-vxlan-tunnel-worker", protocol: "udp", port: "8472", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-geneve-tunnel-worker", protocol: "udp", port: "6081", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Kubernetes master to worker ports
    - { name: "k8s-kubelet-api-master", protocol: "tcp", port: "10250", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "k8s-kubelet-readonly", protocol: "tcp", port: "10255", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "k8s-kubelet-secure", protocol: "tcp", port: "10258", source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Kubernetes worker internal communication
    - { name: "k8s-kubelet-api-worker", protocol: "tcp", port: "10250", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "k8s-nodeports-worker", protocol: "tcp", port: "30000:32767", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "k8s-ingress-http-worker", protocol: "tcp", port: "80", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "k8s-ingress-https-worker", protocol: "tcp", port: "443", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    - { name: "cilium-netperf-worker", protocol: "tcp", port: "12865", source: "{{ k8s_worker_dev_nodes | map(attribute='ipv4') | list }}" }
    
    # Load Balancer access for ingress traffic
    - { name: "k8s-ingress-http-lb", protocol: "tcp", port: "80", source: "{{ k8s_lb_k8s_ingress.ipv4 | first }}" }
    - { name: "k8s-ingress-https-lb", protocol: "tcp", port: "443", source: "{{ k8s_lb_k8s_ingress.ipv4 | first }}" }
```

### Конфигурация Remote State

Файл: `group_vars/k8s_master_c1_dev/remote-state.yml` или `group_vars/k8s_worker_c1_dev/remote-state.yml`

```yaml
---
terraform_states:
  - name: "c1-infra-cloud"
    terraform_provider: "hetzner"
    s3_bucket: "terraform-backend-bucket"
    s3_key: "env/c1-infra-cloud/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "terraform_s3_ro"
    resources:
      - type: "hcloud_server"
        name: "srv_mgmt_01"
      - type: "hcloud_server"
        name: "srv_monitoring_01"
  
  - name: "c1-k8s-dev"
    terraform_provider: "hetzner"
    s3_bucket: "terraform-backend-bucket"
    s3_key: "env/c1-k8s-dev/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "terraform_s3_ro"
    resources:
      - type: "hcloud_load_balancer"
        name: "k8s_master_lb"
      - type: "hcloud_load_balancer"
        name: "k8s_lb_k8s_ingress"
    filter_by_labels:
      - label_key: "fw_k8s"
        label_value: "k8s_master_dev"
        resource_type: "hcloud_server"
        output_var_name: "k8s_master_dev_nodes"
      - label_key: "fw_k8s"
        label_value: "k8s_worker_dev"
        resource_type: "hcloud_server"
        output_var_name: "k8s_worker_dev_nodes"
```

**Важно:** В Terraform серверы должны иметь соответствующие лейблы:
```hcl
resource "hcloud_server" "k8s_master" {
  count = 3
  # ...
  labels = {
    fw_k8s = "k8s_master_dev"
  }
}

resource "hcloud_server" "k8s_worker" {
  count = 5
  # ...
  labels = {
    fw_k8s = "k8s_worker_dev"
  }
}
```

## Использование в playbook

```yaml
---
- hosts: k8s_master_c1_dev
  become: true
  roles:
    - terraform-read-remote-state-g3  # Обязательно первой!
    - ufw-k8s-tf-g1
  tags:
    - ufw
    - ufw-k8s

- hosts: k8s_worker_c1_dev
  become: true
  roles:
    - terraform-read-remote-state-g3  # Обязательно первой!
    - ufw-k8s-tf-g1
  tags:
    - ufw
    - ufw-k8s
```

## Особенности работы с переменными

### Списки IP-адресов

Когда используете `filter_by_labels`, роль `terraform-read-remote-state-g3` создает переменные со списками узлов:

```yaml
k8s_master_dev_nodes:
  - name: "master-01"
    ipv4: "10.0.1.10"
    ipv6: "2001:db8::10"
  - name: "master-02"
    ipv4: "10.0.1.11"
    ipv6: "2001:db8::11"
```

Для извлечения только IP используйте Jinja2 фильтры:
```yaml
source: "{{ k8s_master_dev_nodes | map(attribute='ipv4') | list }}"
# Результат: ["10.0.1.10", "10.0.1.11"]
```

Роль `ufw-k8s-tf-g1` автоматически создаст отдельное UFW правило для каждого IP из списка.

### Load Balancer

Для Load Balancer (обычно без `count`):
```yaml
# Single LB - берем первый элемент из списка
source: "{{ k8s_master_lb.ipv4 | first }}"
# Результат: "167.235.110.61"

# Multiple LB (если используется count) - передаем список
source: "{{ k8s_master_lb.ipv4 }}"
# Результат: ["167.235.110.61", "167.235.110.62"]
```

## Теги

- `ufw` - все UFW операции
- `ufw-all` - все UFW правила
- `ufw-k8s` - только Kubernetes правила
- `ufw-ipv6` - только IPv6 правила

## Требования

- Ubuntu (роль проверяет `ansible_distribution == 'Ubuntu'`)
- Установленный и включенный UFW
- Выполненная роль `terraform-read-remote-state-g3` перед этой ролью
- Доступ к S3 bucket с Terraform state (AWS CLI настроен)

## Примечания

1. **Порядок выполнения критичен** - роль `terraform-read-remote-state-g3` должна быть выполнена первой
2. **IPv6 правила опциональны** - можно оставить пустым если не используется IPv6
3. **Правила применяются инкрементально** - существующие правила не удаляются автоматически
4. **Комментарии в UFW** - параметр `name` используется как комментарий для идентификации правил
5. **Масштабируемость** - при добавлении новых серверов с правильными лейблами в Terraform, они автоматически попадут в правила

