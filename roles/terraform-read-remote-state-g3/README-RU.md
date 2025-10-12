# Роль terraform-read-remote-state-g2

Роль для чтения Terraform state из S3 и извлечения IP-адресов ресурсов из нескольких облачных провайдеров.

## Описание

Роль читает Terraform state файлы из S3 backend и создает переменные с IP-адресами для использования в других ролях, особенно для настройки правил фаервола.

## Поддерживаемые провайдеры

- **Hetzner Cloud** (`hetzner`): `hcloud_server`, `hcloud_load_balancer`
- **DigitalOcean** (`digitalocean`): `digitalocean_droplet`
- **TimeWeb Cloud** (`twc`): `twc_server`

## Конфигурация

### Пример конфигурации в group_vars

```yaml
terraform_states:
  - name: "prod-infra"
    terraform_provider: "hetzner"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-infra/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    resources:
      - type: "hcloud_server"
        name: "management_server"
      - type: "hcloud_server"
        name: "monitoring_server"
        
  - name: "prod-k8s"
    terraform_provider: "hetzner"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-k8s/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    resources:
      - type: "hcloud_server"
        name: "k8s_masters"
```

### Фильтрация по лейблам Terraform

Роль поддерживает фильтрацию ресурсов по лейблам Terraform. Это полезно когда у вас есть множество инстансов созданных через `count` и нужно извлечь все инстансы с определенными лейблами.

```yaml
terraform_states:
  - name: "prod-k8s"
    terraform_provider: "hetzner"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-k8s/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    filter_by_labels:
      - label_key: "role"
        label_value: "ingress"
        resource_type: "hcloud_server"
        output_var_name: "k8s_ingress_nodes"
      - label_key: "role"
        label_value: "worker"
        resource_type: "hcloud_server"
        output_var_name: "k8s_worker_nodes"
```

Опция `filter_by_labels` создает переменную-список со всеми совпадающими инстансами:

```yaml
k8s_ingress_nodes:
  - name: "fsn1-prod-i-50"
    ipv4: "49.13.123.200"
    ipv6: "2a01:4f8:c014:b8ac::1"
  - name: "fsn1-prod-i-51"
    ipv4: "49.13.123.201"
    ipv6: "2a01:4f8:c014:b8ac::2"
```

## Выходные переменные

Роль создает переменные для каждого ресурса в формате `{{ resource_name }}`:

```yaml
# Для ресурса "k8s_masters"
k8s_masters:
  ipv4: ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
  ipv6: ["2001:db8::10", "2001:db8::11", "2001:db8::12"]

# Для ресурса "management_server"  
management_server:
  ipv4: ["10.0.0.100"]
  ipv6: ["2001:db8::100"]
```

## Поддержка count

Роль автоматически поддерживает ресурсы с `count`, извлекая IP-адреса всех экземпляров в массивы.

## Использование в плейбуке

```yaml
---
- hosts: your_hosts
  become: true
  roles:
    - terraform-read-remote-state-g2
    - ufw-rules-tf-g2
```

## Требования

- **AWS CLI** установлен и настроен
- Доступ на чтение к S3 bucket с Terraform state
- Правильно настроенные AWS профили

## Теги

- `tf` - общие операции Terraform
- `always` - выполняется всегда
