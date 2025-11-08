# Роль ufw-rules-tf-g2

Роль для настройки правил UFW фаервола на основе данных из Terraform state.

## Описание

Роль автоматически создает правила UFW фаервола, используя IP-адреса, полученные из роли `terraform-read-remote-state-g3`. Поддерживает как одиночные IP-адреса, так и массивы адресов.

## Зависимости

Роль должна выполняться **после** роли `terraform-read-remote-state-g3`:

```yaml
roles:
  - terraform-read-remote-state-g3
  - ufw-rules-tf-g2
```

## Конфигурация

### Формат правил

```yaml
iptables_rule_g2:
  ipv4:
    - name: "ssh from management"
      protocol: "tcp"
      port: "22"
      source: "{{ management_server.ipv4 | default([]) }}"
    - name: "api access"
      protocol: "tcp" 
      port: "8080"
      source: "{{ k8s_masters.ipv4 | default([]) }}"
      
  ipv6:
    - name: "ssh from management"
      protocol: "tcp"
      port: "22"
      source: "{{ management_server.ipv6 | default([]) }}"
    - name: "monitoring"
      protocol: "tcp"
      port: "9100"
      source: "{{ monitoring_server.ipv6 | default([]) }}"
```

### Параметры правила

- `name` - описание правила (обязательно)
- `protocol` - протокол: tcp/udp (обязательно)
- `port` - порт или диапазон портов (например: "22", "8301:8302")
- `source` - IP-адрес или массив IP-адресов (может быть пустым)
- `rule` - тип правила (по умолчанию: "allow")
- `direction` - направление для IPv6 (по умолчанию: "in")

## Автоматическая обработка источников

Роль автоматически обрабатывает различные форматы источников:

- **Строка**: `"192.168.1.1"` → создает одно правило
- **Массив**: `["192.168.1.1", "192.168.1.2"]` → создает правило для каждого IP
- **Пустой массив**: `[]` → правило пропускается

## Пример конфигурации

```yaml
# В group_vars или в файле конфигурации хоста
iptables_rule_g2:
  ipv4:
    - name: "ssh from management servers"
      protocol: "tcp"
      port: "22"
      source: "{{ management_server.ipv4 | default([]) }}"
    - name: "k8s cluster communication"
      protocol: "tcp"
      port: "6443"
      source: "{{ k8s_masters.ipv4 | default([]) }}"
      
  ipv6:
    - name: "monitoring scrape"
      protocol: "tcp"
      port: "9100"
      source: "{{ monitoring_server.ipv6 | default([]) }}"
```

## Поддерживаемые системы

- Ubuntu (проверяется через `ansible_distribution`)

## Теги

- `ufw` - операции UFW
- `ufw-all` - все операции UFW
- `ufw-ipv6` - только IPv6 правила

## Примечания

- Правила IPv4 добавляются относительно первого IPv4 правила
- Правила IPv6 добавляются относительно последнего IPv6 правила
- При отсутствии источников правило автоматически разрешает доступ с любого адреса (0.0.0.0/0 или ::/0)
