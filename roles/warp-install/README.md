# Cloudflare WARP Install Role

Ansible роль для установки Cloudflare WARP клиента на Linux сервера с настройкой для Zero Trust.

## Особенности

- Поддержка архитектур: amd64, arm64, armhf, i386
- Автоматическое определение архитектуры системы
- Установка через пакетный менеджер (apt/yum)
- Автоматическая настройка для Cloudflare Zero Trust
- Поддержка Debian/Ubuntu и RHEL/CentOS
- Управление системным сервисом

## Переменные

- `warp_organization`: имя организации Cloudflare Zero Trust (опционально)
- `warp_auto_connect`: автоматическое подключение (по умолчанию: true)
- `warp_service_name`: имя системного сервиса (по умолчанию: warp-svc)

## Использование

### Базовая установка
```yaml
- hosts: servers
  become: true
  roles:
    - warp-install
```

### Установка с настройкой Zero Trust
```yaml
- hosts: servers
  become: true
  vars:
    warp_organization: "your-organization-name"
  roles:
    - warp-install
```

### Только установка без настройки
```yaml
- hosts: servers
  become: true
  roles:
    - warp-install
  tags:
    - install
```

## Требования

- Ansible 2.9+
- Доступ к интернету для скачивания WARP
- Права sudo для установки
- Cloudflare Zero Trust аккаунт (для настройки)
