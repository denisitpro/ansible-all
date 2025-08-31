# Description
It is recommended to use a dedicated account for server enrollment in FreeIPA. Additionally, it is recommended to set the password using Vault.

# Need set
* freeipa_join_user
* freeipa_join_password

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