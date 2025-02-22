# Description
* Support for Ubuntu 22.04
* Testing - Hetzner Cloud

# Configuration
Disable redirect - - https://denisitpro.wordpress.com/2019/10/09/freeipa-nginx-%d0%be%d1%82%d0%ba%d0%bb%d1%8e%d1%87%d0%b0%d0%b5%d0%bc-%d1%80%d0%b5%d0%b4%d0%b8%d1%80%d0%b5%d0%ba%d1%82/

To disable the redirect directly to the real freeipa host, locate the file `/opt/freeipa/etc/httpd/conf.d/ipa-rewrite.conf` and comment out the following line:
```
RewriteRule ^/ipa/(.*)      http://ipa-01.example.com/ipa/$1 [L,R=301]
```
After that, restart the ipa services.


# First launch
For first init set variable freeipa_init: true 
need set variable: 
* freeipa admin password `freeipa_admin_password`
* freeipa DS password: `freeipa_ds_password`

Add the example variable for work:
```commandline
freeipa_commands:
  - "ipa-server-install"
  - "--unattended"
  - "--realm={{ internal_domain | upper }}"
  - "--no-ntp"
  - "--no_hbac_allow"
  - "--no-ssh"
  - "--no-sshd"
```

After the first launch and initialization, remove the `freeipa_admin_password` and `freeipa_ds_password` options.

# Example playbook
```commandline
- hosts: ipa_server
  become: true
  roles:
    - 0005-net-interface-check
    - 0010-common-v4
    - docker-install
    - docker-compose
    - vault-get-users-secrets-teleport #optionality
    - freeipa-server-install
    - ufw-base-configure
    - ufw-management


```

# ipa server discovery
For correct work need dns records, examples
```commandline

; ipa settings
; IPA server addition urls - master
_ldap._tcp              IN      SRV     0       100     389     ipa-01.example.com.
_kerberos._udp          IN      SRV     0       100     88      ipa-01.example.com.
_kerberos._tcp          IN      SRV     0       100     88      ipa-01.example.com.
_kerberos-master._udp   IN      SRV     0       100     88      ipa-01.example.com.
_kerberos-master._tcp   IN      SRV     0       100     88      ipa-01.example.com.
_kpasswd._udp           IN      SRV     0       100     464     ipa-01.example.com.
_kpasswd._tcp           IN      SRV     0       100     464     ipa-01.example.com.
_ntp._udp               IN      SRV     0       100     123     ntp.ubuntu.com.
_kerberos               IN      TXT                             "EXAMPLE.COM"
```
