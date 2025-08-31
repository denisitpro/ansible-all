#

## Links
- https://github.com/OpenVPN/easy-rsa/issues/73
- https://securitronlinux.com/bejiitaswrath/how-to-create-keys-with-easy-rsa-without-a-password-prompt/


example create user
```openvpn_users:
  - {name: "test1", address: "10.100.100.101"}
  - {name: "test2", address: "10.100.100.102"}
  - {name: "test3", address: "10.100.100.103"}
  ```

example remove user
```
openvpn:
  remove:
    - {user: test1}
    - {user: test2}
    - {user: test3}
    ```