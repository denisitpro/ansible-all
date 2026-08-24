# Example usage Alpine PSQL 18 + Users + DB + Replication
Установка 
добавить хосты в две переменные

м
добавить пользователей 
psql_users:
- name: "replication"
  password: "{{ vault_psql_replication_pass }}"
  is_replication: true # означает что пользователь используется для репликации
- name: "payload"
  password: "{{ vault_psql_payload_pass }}"

psql_db:
- name: "payload"
  owner: "payload"

vault_psql_replication_pass: "qwerty"
vault_psql_payload_pass: "qwerty"

запустить
ansible-playbook -i inventory site.yml -t psql

Промоут реплики до мастера
1 - убедиться что старый мастер умер
2 - на реплике которую надо сделать мастером выполнить SELECT pg_promote();
3 - убедиться что реплика стала мастером - SELECT pg_is_in_recovery();
должно быть:
pg_is_in_recovery
-------------------
f
(1 row)

4 - исправить переменные согласно новым именам мастера
psql_master_node: "<DNS имя нового мастера >"
psql_replica_nodes:
- "<DNS имя реплики1>"
- "<DNS имя реплики2>"

5 - переключить старые реплики на новый мастер -
ansible-playbook psql-dev-c3-dev.yml -i inventory site.yml -t psql-replication \
--limit <имена реплик для переключения> \
-e psql_force_create_replica=true
