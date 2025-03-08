# required
for work required install jq to localhost

* for mac - brew install jq
* for linux - apt install jq or yum install jq

# Usage

example cert array

section notify and access - optionality

```
certs:
  domains:
    - { name: example.com}
    - { name: site.example.com}
  notify:
    - {name: nginx}
  access:
    - {user: nginx}
```