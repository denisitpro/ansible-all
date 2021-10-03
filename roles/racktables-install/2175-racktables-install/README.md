# example secret.php 
Support LDAP (freeipa) and custom reports - https://github.com/RackTables/racktables-contribs/tree/master/extensions

```$)'
<?php
$pdo_dsn = 'mysql:host=localhost;dbname=racktablesdb';
$db_username = 'racktableuser';
$db_password = 'DBpassword';
$racktables_plugins_dir = '/var/www/html/plugins';
$user_auth_src = 'ldap';
$require_local_account = FALSE;
$LDAP_options = array
(
	'server' => 'ipa.example.com',
	'domain' => '',
	'search_attr' => 'uid',
	'search_dn' => 'cn=users,cn=accounts,dc=example,dc=com',
	'search_bind_rdn' => 'uid=rack_user,cn=sysaccounts,cn=etc,dc=example,dc=com',
	'search_bind_password' => 'BindUserpassword',
	'displayname_attrs' => 'uid',
	'options' => array (LDAP_OPT_PROTOCOL_VERSION => 3),
	'use_tls' => 2,         // 0 == don't attempt, 1 == attempt, 2 == require
);```